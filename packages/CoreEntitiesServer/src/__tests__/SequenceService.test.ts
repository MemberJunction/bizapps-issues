import { describe, it, expect, beforeEach, vi } from 'vitest';

// ---------------------------------------------------------------------------
// SequenceService.assignNextIssueNumber() builds the DB call for the active
// platform (DB_PLATFORM) and returns the formatted IssueNumber the routine emits.
//   * SQL Server: EXEC … @IssueNumber = @x OUTPUT (procedure form).
//   * PostgreSQL: SELECT schema.spAssignNextIssueNumber(:scope) (function form).
// We mock resolveDbPlatformFromEnv to drive the branch, and a provider stub whose
// ExecuteSQL captures the emitted SQL and returns a canned IssueNumber row.
// ---------------------------------------------------------------------------

let platform: 'sqlserver' | 'postgresql' | undefined;
vi.mock('@memberjunction/generic-database-provider', () => ({
  resolveDbPlatformFromEnv: () => platform,
}));

// Avoid pulling the real @memberjunction/core (heavy) — only LogError is used on the error path.
vi.mock('@memberjunction/core', () => ({
  LogError: vi.fn(),
  // BaseEntity / DatabaseProviderBase are type-only imports; provide harmless runtime stubs.
  BaseEntity: class {},
  DatabaseProviderBase: class {},
}));

import { SequenceService } from '../SequenceService.js';

let capturedSQL = '';
let capturedParams: unknown[] | undefined;
let returnedRows: Array<Record<string, unknown>> = [];

function makeEntity(): unknown {
  const provider = {
    ExecuteSQL: vi.fn(async (sql: string, parameters?: unknown[]) => {
      capturedSQL = sql;
      capturedParams = parameters;
      return returnedRows;
    }),
  };
  return { ProviderToUse: provider, ContextCurrentUser: { ID: 'U-1' } };
}

describe('SequenceService.assignNextIssueNumber', () => {
  beforeEach(() => {
    capturedSQL = '';
    capturedParams = undefined;
    returnedRows = [{ IssueNumber: 'MJC-42' }];
  });

  describe('SQL Server dialect', () => {
    beforeEach(() => { platform = 'sqlserver'; });

    it('emits an EXEC … OUTPUT procedure call with the scope bound as a parameter', async () => {
      const v = await SequenceService.assignNextIssueNumber('MJC', makeEntity() as never);
      expect(v).toBe('MJC-42');
      expect(capturedSQL).toContain('EXEC __mj_BizAppsIssues.spAssignNextIssueNumber');
      expect(capturedSQL).toContain('@IssueNumber = @issueNumber OUTPUT');
      expect(capturedSQL).toContain('@AppScope = ?');
      expect(capturedParams).toEqual(['MJC']);
    });

    it('passes NULL inline (no bound parameter) when AppScope is null', async () => {
      await SequenceService.assignNextIssueNumber(null, makeEntity() as never);
      expect(capturedSQL).toContain('@AppScope = NULL');
      expect(capturedParams).toBeUndefined();
    });

    it('never inlines the scope value into the SQL text', async () => {
      await SequenceService.assignNextIssueNumber("O'Brien", makeEntity() as never);
      expect(capturedSQL).not.toContain("O'Brien");
      expect(capturedSQL).not.toContain("O''Brien");
      expect(capturedParams).toEqual(["O'Brien"]);
    });

    it('defaults to SQL Server when DB_PLATFORM is unset', async () => {
      platform = undefined;
      await SequenceService.assignNextIssueNumber('MJC', makeEntity() as never);
      expect(capturedSQL).toContain('EXEC __mj_BizAppsIssues.spAssignNextIssueNumber');
    });
  });

  describe('PostgreSQL dialect', () => {
    beforeEach(() => { platform = 'postgresql'; });

    it('emits a SELECT function call aliased to IssueNumber with a $1 bound scope', async () => {
      const v = await SequenceService.assignNextIssueNumber('MJC', makeEntity() as never);
      expect(v).toBe('MJC-42');
      expect(capturedSQL).toContain('SELECT __mj_BizAppsIssues.spAssignNextIssueNumber($1)');
      expect(capturedSQL).toContain('AS "IssueNumber"');
      expect(capturedParams).toEqual(['MJC']);
      // No T-SQL constructs leak into the PG path.
      expect(capturedSQL).not.toContain('EXEC');
      expect(capturedSQL).not.toContain('OUTPUT');
      expect(capturedSQL).not.toContain('DECLARE');
    });

    it('inlines NULL (no bound parameter) when AppScope is null', async () => {
      await SequenceService.assignNextIssueNumber(null, makeEntity() as never);
      expect(capturedSQL).toContain('spAssignNextIssueNumber(NULL)');
      expect(capturedParams).toBeUndefined();
    });

    it('never inlines the scope value into the SQL text', async () => {
      await SequenceService.assignNextIssueNumber("O'Brien", makeEntity() as never);
      expect(capturedSQL).not.toContain("O'Brien");
      expect(capturedSQL).not.toContain("O''Brien");
      expect(capturedParams).toEqual(["O'Brien"]);
    });
  });

  describe('error handling', () => {
    beforeEach(() => { platform = 'sqlserver'; });

    it('throws when the routine returns no value', async () => {
      returnedRows = [];
      await expect(
        SequenceService.assignNextIssueNumber('MJC', makeEntity() as never),
      ).rejects.toThrow(/returned no value/);
    });

    it('throws when the entity has no provider', async () => {
      await expect(
        SequenceService.assignNextIssueNumber('MJC', { ProviderToUse: undefined } as never),
      ).rejects.toThrow(/no provider/);
    });
  });
});
