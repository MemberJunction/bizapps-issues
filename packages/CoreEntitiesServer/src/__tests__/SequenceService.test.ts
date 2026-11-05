import { describe, it, expect, beforeEach, vi } from 'vitest';
import type { BaseEntity } from '@memberjunction/core';

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
  DocumentNumberingEngine: {
    Instance: {
      RegisterPolicy: vi.fn(),
    },
  },
}));

import { SequenceService } from '../SequenceService.js';

let capturedSQL = '';
let returnedRows: Array<Record<string, string | number>> = [];

function makeEntity(): BaseEntity {
  const provider = {
    ExecuteSQL: vi.fn(async (sql: string) => {
      capturedSQL = sql;
      return returnedRows;
    }),
  };
  return { ProviderToUse: provider, ContextCurrentUser: { ID: 'U-1' } } as object as BaseEntity;
}

describe('SequenceService.assignNextIssueNumber', () => {
  beforeEach(() => {
    capturedSQL = '';
    returnedRows = [{ IssueNumber: 'MJC-42' }];
  });

  describe('SQL Server dialect', () => {
    beforeEach(() => { platform = 'sqlserver'; });

    it('emits an EXEC … OUTPUT procedure call', async () => {
      const v = await SequenceService.assignNextIssueNumber('MJC', makeEntity());
      expect(v).toBe('MJC-42');
      expect(capturedSQL).toContain('EXEC __mj_BizAppsIssues.spAssignNextIssueNumber');
      expect(capturedSQL).toContain('@IssueNumber = @issueNumber OUTPUT');
      expect(capturedSQL).toContain("@AppScope = N'MJC'");
    });

    it('passes NULL (not a literal) when AppScope is null', async () => {
      await SequenceService.assignNextIssueNumber(null, makeEntity());
      expect(capturedSQL).toContain('@AppScope = NULL');
    });

    it('escapes single quotes in the scope literal', async () => {
      await SequenceService.assignNextIssueNumber("O'Brien", makeEntity());
      expect(capturedSQL).toContain("N'O''Brien'");
    });

    it('defaults to SQL Server when DB_PLATFORM is unset', async () => {
      platform = undefined;
      await SequenceService.assignNextIssueNumber('MJC', makeEntity());
      expect(capturedSQL).toContain('EXEC __mj_BizAppsIssues.spAssignNextIssueNumber');
    });
  });

  describe('PostgreSQL dialect', () => {
    beforeEach(() => { platform = 'postgresql'; });

    it('emits a SELECT function call aliased to IssueNumber', async () => {
      const v = await SequenceService.assignNextIssueNumber('MJC', makeEntity());
      expect(v).toBe('MJC-42');
      expect(capturedSQL).toContain('SELECT __mj_BizAppsIssues.spAssignNextIssueNumber(');
      expect(capturedSQL).toContain('AS "IssueNumber"');
      // No T-SQL constructs leak into the PG path.
      expect(capturedSQL).not.toContain('EXEC');
      expect(capturedSQL).not.toContain('OUTPUT');
      expect(capturedSQL).not.toContain('DECLARE');
    });

    it('inlines NULL when AppScope is null', async () => {
      await SequenceService.assignNextIssueNumber(null, makeEntity());
      expect(capturedSQL).toContain('spAssignNextIssueNumber(NULL)');
    });

    it('escapes single quotes with a plain (non-N) literal', async () => {
      await SequenceService.assignNextIssueNumber("O'Brien", makeEntity());
      expect(capturedSQL).toContain("'O''Brien'");
      expect(capturedSQL).not.toContain("N'O''Brien'");
    });
  });

  describe('error handling', () => {
    beforeEach(() => { platform = 'sqlserver'; });

    it('throws when the routine returns no value', async () => {
      returnedRows = [];
      await expect(
        SequenceService.assignNextIssueNumber('MJC', makeEntity()),
      ).rejects.toThrow(/returned no value/);
    });

    it('throws when the entity has no provider', async () => {
      await expect(
        SequenceService.assignNextIssueNumber('MJC', { ProviderToUse: undefined } as object as BaseEntity),
      ).rejects.toThrow(/no provider/);
    });
  });
});
