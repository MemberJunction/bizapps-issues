import {
  BaseEntity,
  DatabaseProviderBase,
  DocumentNumberingEngine,
  LogError,
  type DocumentSequenceAllocationRequest,
  type IDocumentNumberPolicy,
  type IDocumentSequenceStore,
} from '@memberjunction/core';
import { resolveDbPlatformFromEnv } from '@memberjunction/generic-database-provider';

const ISSUES_SCHEMA = '__mj_BizAppsIssues';

export const ISSUES_ENTITY_NAME = 'MJ_BizApps_Issues: Issues';

/**
 * Declarative `DocumentNumberingEngine` policy for `MJ_BizApps_Issues: Issues.IssueNumber`.
 *
 * Pattern `{Field:AppScope:UPPER:ISS}-{SEQ:1}` normalizes `AppScope` (trimmed + uppercased,
 * falling back to `'ISS'` when null/blank) and appends the 1-based per-scope counter.
 */
export const ISSUE_NUMBERING_POLICY: IDocumentNumberPolicy = {
  targetField: 'IssueNumber',
  sequenceKey: 'MJ_BizApps_Issues: Issues.IssueNumber',
  pattern: '{Field:AppScope:UPPER:ISS}-{SEQ:1}',
  scopeFields: ['AppScope'],
  scopeFieldFallbacks: { AppScope: 'ISS' },
  startAt: 1,
  incrementBy: 1,
  manualValueMode: 'AllowAny',
  immutableAfterCreate: true,
};

/**
 * Registers the `MJ_BizApps_Issues: Issues` auto-numbering policy on `DocumentNumberingEngine.Instance`.
 * Safe to call repeatedly (idempotent) and resilient when `@memberjunction/core` is partially mocked in unit tests.
 */
export function registerIssueNumberingPolicy(): void {
  const engine = (DocumentNumberingEngine as { Instance?: DocumentNumberingEngine } | undefined)?.Instance;
  engine?.RegisterPolicy?.(ISSUES_ENTITY_NAME, ISSUE_NUMBERING_POLICY);
}

registerIssueNumberingPolicy();

/**
 * Sequence store adapter bridging `DocumentNumberingEngine` counter allocation to the
 * database-level `spAssignNextIssueNumber` routine (SQL Server procedure or PostgreSQL function).
 */
export class CustomRoutineDocumentSequenceStore implements IDocumentSequenceStore {
  public async AllocateNext(request: DocumentSequenceAllocationRequest): Promise<number> {
    const scopeMatch = /(?:^|\|)Field:AppScope=([^|]+)/.exec(request.scopeKey);
    const rawScope = scopeMatch?.[1]?.trim() ?? null;
    const platform = resolveDbPlatformFromEnv() ?? request.provider.PlatformKey ?? 'sqlserver';
    const sql = SequenceService.buildRoutineSQLForPlatform(platform, rawScope);

    const rows = await request.provider.ExecuteSQL<{ IssueNumber?: string; AllocatedValue?: number | string }>(
      sql,
      undefined,
      { isMutation: true, description: 'spAssignNextIssueNumber' },
      request.contextUser,
    );

    const firstRow = rows?.[0];
    if (typeof firstRow?.AllocatedValue === 'number' && Number.isFinite(firstRow.AllocatedValue)) {
      return firstRow.AllocatedValue;
    }
    const issueNumber = firstRow?.IssueNumber;
    if (typeof issueNumber === 'string' && issueNumber.length > 0) {
      const dashIdx = issueNumber.lastIndexOf('-');
      const seqPart = dashIdx >= 0 ? issueNumber.slice(dashIdx + 1) : issueNumber;
      const parsed = Number.parseInt(seqPart, 10);
      if (Number.isFinite(parsed)) {
        return parsed;
      }
    }

    throw new Error(
      `CustomRoutineDocumentSequenceStore: routine returned no value for scopeKey=${request.scopeKey}`,
    );
  }
}

interface ProviderCarrier {
  ProviderToUse?: DatabaseProviderBase;
}

/**
 * SequenceService — integrates `DocumentNumberingEngine` policy registration and pattern
 * formatting for `MJ_BizApps_Issues: Issues` with the DB-level atomic numbering routine
 * (`spAssignNextIssueNumber`) so `IssueEntityServer` assigns `IssueNumber` before `super.Save()`.
 *
 * Platform-aware: MemberJunction runs on SQL Server or PostgreSQL, and the two
 * expose the routine differently —
 *   * SQL Server: a PROCEDURE with an OUTPUT parameter, invoked via
 *     `DECLARE @x …; EXEC … @IssueNumber = @x OUTPUT; SELECT @x`.
 *   * PostgreSQL: a FUNCTION RETURNING TEXT (PG has no clean OUTPUT-param EXEC
 *     idiom), invoked via `SELECT schema.spAssignNextIssueNumber(:scope)`.
 */
export class SequenceService {
  /**
   * Formats an `IssueNumber` for the given `appScope` and 1-based `sequenceNumber`
   * using `DocumentNumberingEngine` and {@link ISSUE_NUMBERING_POLICY}.
   */
  public static formatIssueNumber(
    appScope: string | null,
    sequenceNumber: number,
    entity?: BaseEntity,
  ): string {
    const engine = (DocumentNumberingEngine as { Instance?: DocumentNumberingEngine } | undefined)?.Instance;
    if (engine?.FormatPattern) {
      const targetEntity = this.createScopeEntityView(appScope, entity);
      const now = new Date();
      return engine.FormatPattern(
        ISSUE_NUMBERING_POLICY,
        sequenceNumber,
        targetEntity,
        entity?.ContextCurrentUser,
        now,
        now.getUTCFullYear(),
      );
    }
    const normalizedScope = appScope && appScope.trim().length > 0 ? appScope.trim().toUpperCase() : 'ISS';
    return `${normalizedScope}-${sequenceNumber}`;
  }

  /**
   * Derives the `DocumentNumberingEngine` partition `ScopeKey` for a given `appScope`.
   */
  public static buildIssueScopeKey(appScope: string | null, entity?: BaseEntity): string {
    const engine = (DocumentNumberingEngine as { Instance?: DocumentNumberingEngine } | undefined)?.Instance;
    if (engine?.BuildScopeKey) {
      const targetEntity = this.createScopeEntityView(appScope, entity);
      const now = new Date();
      return engine.BuildScopeKey(
        targetEntity,
        ISSUE_NUMBERING_POLICY,
        entity?.ContextCurrentUser,
        now,
        now.getUTCFullYear(),
      );
    }
    const normalizedScope = appScope && appScope.trim().length > 0 ? appScope.trim() : 'ISS';
    return `Field:AppScope=${normalizedScope}`;
  }

  /**
   * Atomically allocates the next IssueNumber for the given AppScope and returns the
   * formatted value (e.g. `MJC-42`, or `ISS-7` when AppScope is null/blank).
   *
   * The provider is taken from the calling entity so the call runs on the same
   * (per-request) provider that owns the entity — never the process-global default.
   *
   * @param appScope The Issue's AppScope (may be null/blank — defaults to 'ISS').
   * @param entity   The Issue entity instance driving the save (supplies the provider + user).
   */
  public static async assignNextIssueNumber(
    appScope: string | null,
    entity: BaseEntity,
  ): Promise<string> {
    registerIssueNumberingPolicy();

    const provider = (entity as object as ProviderCarrier).ProviderToUse;
    if (!provider) {
      LogError('SequenceService.assignNextIssueNumber: entity has no provider');
      throw new Error('SequenceService: no provider available on the entity');
    }

    // DB_PLATFORM defaults to SQL Server when unset (resolveDbPlatformFromEnv returns undefined).
    const platform = resolveDbPlatformFromEnv() ?? 'sqlserver';
    const sql = this.buildRoutineSQLForPlatform(platform, appScope);

    const rows = await provider.ExecuteSQL<{ IssueNumber?: string; AllocatedValue?: number | string }>(
      sql,
      undefined,
      { isMutation: true, description: 'spAssignNextIssueNumber' },
      entity.ContextCurrentUser,
    );

    const firstRow = rows?.[0];
    const value = firstRow?.IssueNumber;
    if (typeof value === 'string' && value.length > 0) {
      return value;
    }

    const allocated = firstRow?.AllocatedValue;
    if (typeof allocated === 'number' || (typeof allocated === 'string' && allocated.trim().length > 0)) {
      const seqNum = Number(allocated);
      if (Number.isFinite(seqNum)) {
        return this.formatIssueNumber(appScope, seqNum, entity);
      }
    }

    throw new Error(
      `SequenceService.assignNextIssueNumber: routine returned no value for AppScope=${appScope ?? '(null)'}`,
    );
  }

  /**
   * Builds the platform-specific SQL statement invoking `spAssignNextIssueNumber`.
   */
  public static buildRoutineSQLForPlatform(
    platform: 'sqlserver' | 'postgresql',
    appScope: string | null,
  ): string {
    return platform === 'postgresql'
      ? this.buildPostgresSQL(appScope)
      : this.buildSqlServerSQL(appScope);
  }

  /**
   * SQL Server: call the OUTPUT-parameter procedure and surface its value as a column.
   * The proc re-normalizes the scope regardless of what we pass; we inline it as an escaped
   * literal (the verified pattern across MJ's generated resolvers, which pass `undefined` params).
   */
  private static buildSqlServerSQL(appScope: string | null): string {
    const scopeLiteral = appScope == null ? 'NULL' : `N'${appScope.replace(/'/g, "''")}'`;
    return `
      DECLARE @issueNumber NVARCHAR(50);
      EXEC ${ISSUES_SCHEMA}.spAssignNextIssueNumber
          @AppScope = ${scopeLiteral},
          @IssueNumber = @issueNumber OUTPUT;
      SELECT @issueNumber AS IssueNumber;
    `;
  }

  /**
   * PostgreSQL: call the function form and alias its scalar result to the `IssueNumber` column the
   * caller reads. The function name is emitted UNQUOTED so PostgreSQL folds it to the same lowercase
   * identifier the `CREATE FUNCTION` produced. The schema is likewise unquoted (folds to lowercase),
   * matching how `mj codegen` and the MJServer runtime reference app-schema objects on PG.
   */
  private static buildPostgresSQL(appScope: string | null): string {
    const scopeLiteral = appScope == null ? 'NULL' : `'${appScope.replace(/'/g, "''")}'`;
    return `SELECT ${ISSUES_SCHEMA}.spAssignNextIssueNumber(${scopeLiteral}) AS "IssueNumber";`;
  }

  private static createScopeEntityView(appScope: string | null, entity?: BaseEntity): BaseEntity {
    const stub = {
      EntityInfo: entity?.EntityInfo ?? { Name: ISSUES_ENTITY_NAME },
      GetFieldByName: (name: string): { Value: string | null } | null => {
        if (name === 'AppScope') {
          return { Value: appScope };
        }
        return entity?.GetFieldByName ? entity.GetFieldByName(name) : null;
      },
    };
    return stub as object as BaseEntity;
  }
}
