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
let capturedParams: string[] | undefined;
let returnedRows: Array<Record<string, string | number>> = [];

function makeEntity(): BaseEntity {
  const provider = {
    ExecuteSQL: vi.fn(async (sql: string, parameters?: string[]) => {
      capturedSQL = sql;
      capturedParams = parameters;
      return returnedRows;
    }),
  };
  return { ProviderToUse: provider, ContextCurrentUser: { ID: 'U-1' } } as object as BaseEntity;
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
      const v = await SequenceService.assignNextIssueNumber('MJC', makeEntity());
      expect(v).toBe('MJC-42');
      expect(capturedSQL).toContain('EXEC __mj_BizAppsIssues.spAssignNextIssueNumber');
      expect(capturedSQL).toContain('@IssueNumber = @issueNumber OUTPUT');
      expect(capturedSQL).toContain('@AppScope = ?');
      expect(capturedParams).toEqual(['MJC']);
    });

    it('passes NULL inline (no bound parameter) when AppScope is null', async () => {
      await SequenceService.assignNextIssueNumber(null, makeEntity());
      expect(capturedSQL).toContain('@AppScope = NULL');
      expect(capturedParams).toBeUndefined();
    });

    it('never inlines the scope value into the SQL text', async () => {
      await SequenceService.assignNextIssueNumber("O'Brien", makeEntity());
      expect(capturedSQL).not.toContain("O'Brien");
      expect(capturedSQL).not.toContain("O''Brien");
      expect(capturedParams).toEqual(["O'Brien"]);
    });

    it('strips NUL bytes before binding the scope parameter', async () => {
      await SequenceService.assignNextIssueNumber('MJC\0evil', makeEntity());
      expect(capturedSQL).toContain('@AppScope = ?');
      expect(capturedParams).toEqual(['MJCevil']);
    });

    it('truncates the scope to 50 characters before binding', async () => {
      const longScope = 'A'.repeat(60);
      await SequenceService.assignNextIssueNumber(longScope, makeEntity());
      expect(capturedSQL).toContain('@AppScope = ?');
      expect(capturedParams).toEqual(['A'.repeat(50)]);
    });

    it('collapses a blank scope to NULL (routine defaults it to ISS)', async () => {
      await SequenceService.assignNextIssueNumber('   ', makeEntity());
      expect(capturedSQL).toContain('@AppScope = NULL');
      expect(capturedParams).toBeUndefined();
    });

    it('defaults to SQL Server when DB_PLATFORM is unset', async () => {
      platform = undefined;
      await SequenceService.assignNextIssueNumber('MJC', makeEntity());
      expect(capturedSQL).toContain('EXEC __mj_BizAppsIssues.spAssignNextIssueNumber');
      expect(capturedSQL).toContain('@AppScope = ?');
      expect(capturedParams).toEqual(['MJC']);
    });
  });

  describe('PostgreSQL dialect', () => {
    beforeEach(() => { platform = 'postgresql'; });

    it('emits a SELECT function call aliased to IssueNumber with a $1 bound scope', async () => {
      const v = await SequenceService.assignNextIssueNumber('MJC', makeEntity());
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
      await SequenceService.assignNextIssueNumber(null, makeEntity());
      expect(capturedSQL).toContain('spAssignNextIssueNumber(NULL)');
      expect(capturedParams).toBeUndefined();
    });

    it('never inlines the scope value into the SQL text', async () => {
      await SequenceService.assignNextIssueNumber("O'Brien", makeEntity());
      expect(capturedSQL).not.toContain("O'Brien");
      expect(capturedSQL).not.toContain("O''Brien");
      expect(capturedParams).toEqual(["O'Brien"]);
    });

    it('strips NUL bytes and truncates to 50 characters before binding', async () => {
      await SequenceService.assignNextIssueNumber(`MJC\0${'B'.repeat(60)}`, makeEntity());
      expect(capturedSQL).toContain('spAssignNextIssueNumber($1)');
      expect(capturedParams).toEqual([`MJC${'B'.repeat(47)}`]);
    });

    it('collapses a blank scope to NULL (no bound parameter)', async () => {
      await SequenceService.assignNextIssueNumber('  \0  ', makeEntity());
      expect(capturedSQL).toContain('spAssignNextIssueNumber(NULL)');
      expect(capturedParams).toBeUndefined();
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
