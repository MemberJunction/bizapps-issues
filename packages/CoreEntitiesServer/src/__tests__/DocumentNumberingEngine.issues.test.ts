import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('@memberjunction/generic-database-provider', () => ({
  resolveDbPlatformFromEnv: () => 'sqlserver',
}));

import {
  BaseEntity,
  DatabaseProviderBase,
  DocumentNumberingEngine,
  EntityInfo,
  InMemoryDocumentSequenceStore,
  ValidationResult,
} from '@memberjunction/core';
import {
  CustomRoutineDocumentSequenceStore,
  ISSUES_ENTITY_NAME,
  ISSUE_NUMBERING_POLICY,
  SequenceService,
  registerIssueNumberingPolicy,
} from '../SequenceService.js';

interface FakeField {
  Name: string;
  Value: string | null;
  OldValue: string | null;
  Dirty: boolean;
}

function makeIssueEntityStub(opts: {
  appScope: string | null;
  issueNumber?: string | null;
  isSaved?: boolean;
  oldIssueNumber?: string | null;
}): { entity: BaseEntity; fields: Record<string, FakeField> } {
  const issueNum = opts.issueNumber ?? null;
  const oldNum = opts.oldIssueNumber !== undefined ? opts.oldIssueNumber : issueNum;
  const fields: Record<string, FakeField> = {
    AppScope: {
      Name: 'AppScope',
      Value: opts.appScope,
      OldValue: opts.appScope,
      Dirty: false,
    },
    IssueNumber: {
      Name: 'IssueNumber',
      Value: issueNum,
      OldValue: oldNum,
      Dirty: issueNum !== oldNum,
    },
  };

  const entity = {
    EntityInfo: { Name: ISSUES_ENTITY_NAME } as object as EntityInfo,
    IsSaved: opts.isSaved ?? false,
    GetFieldByName: (name: string) => fields[name] ?? null,
    ContextCurrentUser: undefined,
  } as object as BaseEntity;

  return { entity, fields };
}

describe('DocumentNumberingEngine integration for MJ_BizApps_Issues: Issues', () => {
  beforeEach(() => {
    DocumentNumberingEngine.Instance.ClearProgrammaticPolicies();
    registerIssueNumberingPolicy();
  });

  afterEach(() => {
    DocumentNumberingEngine.Instance.ClearProgrammaticPolicies();
    registerIssueNumberingPolicy();
  });

  it('registers ISSUE_NUMBERING_POLICY on DocumentNumberingEngine.Instance', () => {
    const entityInfo = { Name: ISSUES_ENTITY_NAME } as object as EntityInfo;
    const policies = DocumentNumberingEngine.Instance.ResolvePolicies(entityInfo);
    expect(policies).toHaveLength(1);
    expect(policies[0]).toMatchObject({
      targetField: 'IssueNumber',
      pattern: '{Field:AppScope:UPPER:ISS}-{SEQ:1}',
      scopeFields: ['AppScope'],
      scopeFieldFallbacks: { AppScope: 'ISS' },
      startAt: 1,
      incrementBy: 1,
      immutableAfterCreate: true,
    });
    expect(DocumentNumberingEngine.Instance.WillAutoPopulateOnCreate(entityInfo, 'IssueNumber')).toBe(true);
  });

  it('formats IssueNumber with uppercased AppScope and ISS fallback via DocumentNumberingEngine', () => {
    expect(SequenceService.formatIssueNumber('mjc', 42)).toBe('MJC-42');
    expect(SequenceService.formatIssueNumber('  crm  ', 1)).toBe('CRM-1');
    expect(SequenceService.formatIssueNumber(null, 7)).toBe('ISS-7');
    expect(SequenceService.formatIssueNumber('   ', 19)).toBe('ISS-19');
  });

  it('builds deterministic per-AppScope ScopeKeys with ISS fallback', () => {
    expect(SequenceService.buildIssueScopeKey('MJC')).toBe('Field:AppScope=MJC');
    expect(SequenceService.buildIssueScopeKey(null)).toBe('Field:AppScope=ISS');
    expect(SequenceService.buildIssueScopeKey('')).toBe('Field:AppScope=ISS');
  });

  it('allocates independent sequence numbers per AppScope via InMemoryDocumentSequenceStore', async () => {
    const store = new InMemoryDocumentSequenceStore();
    DocumentNumberingEngine.Instance.SetSequenceStore(store);
    const fakeProvider = {} as object as DatabaseProviderBase;

    const firstMjc = makeIssueEntityStub({ appScope: 'mjc' });
    await DocumentNumberingEngine.Instance.AllocateAndAssignForEntity(firstMjc.entity, fakeProvider, undefined);
    expect(firstMjc.fields.IssueNumber.Value).toBe('MJC-1');

    const secondMjc = makeIssueEntityStub({ appScope: 'mjc' });
    await DocumentNumberingEngine.Instance.AllocateAndAssignForEntity(secondMjc.entity, fakeProvider, undefined);
    expect(secondMjc.fields.IssueNumber.Value).toBe('MJC-2');

    const firstNullScope = makeIssueEntityStub({ appScope: null });
    await DocumentNumberingEngine.Instance.AllocateAndAssignForEntity(firstNullScope.entity, fakeProvider, undefined);
    expect(firstNullScope.fields.IssueNumber.Value).toBe('ISS-1');
  });

  it('enforces post-create immutability on IssueNumber via ValidateAutoNumberFields', () => {
    const savedEdited = makeIssueEntityStub({
      appScope: 'MJC',
      isSaved: true,
      oldIssueNumber: 'MJC-10',
      issueNumber: 'MJC-99',
    });
    const result = new ValidationResult();
    result.Success = true;
    DocumentNumberingEngine.Instance.ValidateAutoNumberFields(savedEdited.entity, result);
    expect(result.Success).toBe(false);
    expect(result.Errors.some((e) => e.Source === 'IssueNumber' && e.Message.includes('cannot be modified after creation'))).toBe(
      true,
    );
  });

  it('bridges DocumentNumberingEngine allocation to spAssignNextIssueNumber via CustomRoutineDocumentSequenceStore', async () => {
    const routineStore = new CustomRoutineDocumentSequenceStore();
    DocumentNumberingEngine.Instance.SetSequenceStore(routineStore);

    let capturedSQL = '';
    const provider = {
      PlatformKey: 'sqlserver',
      ExecuteSQL: vi.fn(async (sql: string) => {
        capturedSQL = sql;
        return [{ IssueNumber: 'MJC-55' }];
      }),
    } as object as DatabaseProviderBase;

    const issue = makeIssueEntityStub({ appScope: 'MJC' });
    const assigned = await DocumentNumberingEngine.Instance.AllocateAndAssignForEntity(issue.entity, provider, undefined);
    expect(assigned).toEqual(['IssueNumber']);
    expect(issue.fields.IssueNumber.Value).toBe('MJC-55');
    expect(capturedSQL).toContain('spAssignNextIssueNumber');
    expect(ISSUE_NUMBERING_POLICY.pattern).toBe('{Field:AppScope:UPPER:ISS}-{SEQ:1}');
  });
});
