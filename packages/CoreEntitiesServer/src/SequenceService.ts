import { BaseEntity, DatabaseProviderBase, LogError } from '@memberjunction/core';
import { resolveDbPlatformFromEnv } from '@memberjunction/generic-database-provider';

const ISSUES_SCHEMA = '__mj_BizAppsIssues';

/**
 * SequenceService — calls the DB-level atomic numbering routine (spAssignNextIssueNumber)
 * from TypeScript so the IssueEntityServer hook can assign IssueNumber before
 * super.Save() commits the row.
 *
 * The routine is intentionally kept at DB level because it requires atomic
 * read-modify-write semantics that don't translate safely to app-level code
 * under concurrency. It normalizes the scope (trim/UPPER, null/blank → 'ISS')
 * and returns the formatted, unpadded `{SCOPE}-{seq}`.
 *
 * Platform-aware: MemberJunction runs on SQL Server or PostgreSQL, and the two
 * expose the routine differently —
 *   * SQL Server: a PROCEDURE with an OUTPUT parameter, invoked via
 *     `DECLARE @x …; EXEC … @IssueNumber = @x OUTPUT; SELECT @x`.
 *   * PostgreSQL: a FUNCTION RETURNING TEXT (PG has no clean OUTPUT-param EXEC
 *     idiom), invoked via `SELECT schema.spAssignNextIssueNumber(:scope)`. The
 *     PG definition ships as a `.pg-only.sql` supplement under `migrations-pg/`.
 * The dialect is selected from `DB_PLATFORM` (the same env var the MJ CLI and
 * runtime use), defaulting to SQL Server when unset — matching the rest of the stack.
 */
export class SequenceService {
  /**
   * Atomically allocates the next IssueNumber for the given AppScope and returns the
   * formatted value (e.g. `MJC-42`, or `ISS-7` when AppScope is null/blank).
   *
   * The provider is taken from the calling entity so the call runs on the same
   * (per-request) provider that owns the entity — never the process-global default.
   *
   * @param appScope The Issue's AppScope (may be null/blank — the routine defaults it to 'ISS').
   * @param entity   The Issue entity instance driving the save (supplies the provider + user).
   */
  public static async assignNextIssueNumber(
    appScope: string | null,
    entity: BaseEntity,
  ): Promise<string> {
    // ProviderToUse is typed IEntityDataProvider, but every concrete MJ provider (SQL Server /
    // PostgreSQL) is a DatabaseProviderBase subclass that also implements IEntityDataProvider. The two
    // interfaces don't structurally overlap, so TS requires the widening cast through `unknown` — this
    // is the sanctioned mechanism for a cast between compatible-at-runtime types, NOT an `any` escape.
    const provider = entity.ProviderToUse as unknown as DatabaseProviderBase | undefined;
    if (!provider) {
      LogError('SequenceService.assignNextIssueNumber: entity has no provider');
      throw new Error('SequenceService: no provider available on the entity');
    }

    // DB_PLATFORM defaults to SQL Server when unset (resolveDbPlatformFromEnv returns undefined).
    const platform = resolveDbPlatformFromEnv() ?? 'sqlserver';
    const sql =
      platform === 'postgresql'
        ? this.buildPostgresSQL(appScope)
        : this.buildSqlServerSQL(appScope);

    const rows = await provider.ExecuteSQL(
      sql,
      undefined,
      { isMutation: true, description: 'spAssignNextIssueNumber' },
      entity.ContextCurrentUser,
    );

    const value = (rows?.[0] as { IssueNumber?: unknown } | undefined)?.IssueNumber;
    if (!value || typeof value !== 'string') {
      throw new Error(
        `SequenceService.assignNextIssueNumber: routine returned no value for AppScope=${appScope ?? '(null)'}`,
      );
    }
    return value;
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
}
