import { BaseEntity, LogError } from '@memberjunction/core';
import { SQLServerDataProvider } from '@memberjunction/sqlserver-dataprovider';

const ISSUES_SCHEMA = '__mj_BizAppsIssues';

/**
 * SequenceService — calls the DB-level atomic numbering proc (spAssignNextIssueNumber)
 * from TypeScript so the IssueEntityServer hook can assign IssueNumber before
 * super.Save() commits the row.
 *
 * The proc is intentionally kept at DB level because it requires atomic
 * HOLDLOCK + UPDLOCK read-modify-write semantics that don't translate safely to
 * app-level code under concurrency. The proc normalizes the scope (trim/UPPER,
 * null/blank → 'ISS') and returns the formatted, unpadded `{SCOPE}-{seq}`.
 */
export class SequenceService {
  /**
   * Atomically allocates the next IssueNumber for the given AppScope and returns the
   * formatted value (e.g. `MJC-42`, or `ISS-7` when AppScope is null/blank).
   *
   * The provider is taken from the calling entity so the call runs on the same
   * (per-request) provider that owns the entity — never the process-global default.
   *
   * @param appScope The Issue's AppScope (may be null/blank — proc defaults it to 'ISS').
   * @param entity   The Issue entity instance driving the save (supplies the provider + user).
   */
  public static async assignNextIssueNumber(
    appScope: string | null,
    entity: BaseEntity,
  ): Promise<string> {
    const provider = entity.ProviderToUse as SQLServerDataProvider | undefined;
    if (!provider) {
      LogError('SequenceService.assignNextIssueNumber: entity has no provider');
      throw new Error('SequenceService: no provider available on the entity');
    }

    // Inline the scope as an escaped SQL literal and pass undefined params — the
    // verified pattern across MJ's generated resolvers (which build EXEC calls as
    // strings and pass `undefined` for parameters). The proc re-normalizes the scope
    // (trim/UPPER, null/blank → 'ISS') regardless of what we pass.
    const scopeLiteral =
      appScope == null ? 'NULL' : `N'${appScope.replace(/'/g, "''")}'`;
    const sql = `
      DECLARE @issueNumber NVARCHAR(50);
      EXEC ${ISSUES_SCHEMA}.spAssignNextIssueNumber
          @AppScope = ${scopeLiteral},
          @IssueNumber = @issueNumber OUTPUT;
      SELECT @issueNumber AS IssueNumber;
    `;
    const rows = await provider.ExecuteSQL(
      sql,
      undefined,
      { isMutation: true, description: 'spAssignNextIssueNumber' },
      entity.ContextCurrentUser,
    );

    const value = rows?.[0]?.IssueNumber;
    if (!value || typeof value !== 'string') {
      throw new Error(
        `SequenceService.assignNextIssueNumber: proc returned no value for AppScope=${appScope ?? '(null)'}`,
      );
    }
    return value;
  }
}
