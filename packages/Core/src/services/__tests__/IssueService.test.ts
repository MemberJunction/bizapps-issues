import { describe, it, expect, beforeEach, vi } from 'vitest';

// ---------------------------------------------------------------------------
// IssueService is now a THIN convenience layer: it resolves type/status and sets
// fields, then calls entity.Save(). The authoritative lifecycle side-effects
// (ResolvedAt/ClosedAt stamping + action-hook firing) live in IssueEntityServer,
// NOT here — so these tests assert only that the service sets the right fields and
// saves. (IssueEntityServer.test.ts covers the stamping/hook behavior.)
//
// We mock:
//   - @memberjunction/core → Metadata (GetEntityObject) + LogError
//   - ../IssueEngine.js    → lookups (DefaultStatus, IssueStatusByID, IssueType*)
// ---------------------------------------------------------------------------

const getEntityObjectMock = vi.fn();

vi.mock('@memberjunction/core', () => ({
  Metadata: class {
    GetEntityObject(...args: unknown[]) {
      return getEntityObjectMock(...args);
    }
  },
  UserInfo: class {},
  LogError: vi.fn(),
}));

const engineState = {
  defaultStatus: { ID: 'S-NEW' } as { ID: string } | undefined,
  statusById: new Map<string, { ID: string; IsTerminal: boolean }>(),
  terminalStatuses: [] as { ID: string; IsTerminal: boolean }[],
  typeById: new Map<string, { ID: string; DefaultPriority: string }>(),
  typeByName: new Map<string, { ID: string; DefaultPriority: string }>(),
};
vi.mock('../IssueEngine.js', () => ({
  IssueEngine: {
    Instance: {
      Config: vi.fn(async () => undefined),
      get DefaultStatus() {
        return engineState.defaultStatus;
      },
      get IssueStatuses() {
        return engineState.terminalStatuses;
      },
      IssueStatusByID: (id: string) => engineState.statusById.get(id),
      IssueTypeByID: (id: string) => engineState.typeById.get(id),
      IssueTypeByName: (n: string) => engineState.typeByName.get(n.trim().toLowerCase()),
    },
  },
}));

import { IssueService } from '../IssueService.js';

interface FakeIssue {
  [key: string]: unknown;
  NewRecord: ReturnType<typeof vi.fn>;
  Save: ReturnType<typeof vi.fn>;
  LatestResult?: { CompleteMessage: string };
}
function makeFakeIssue(saveResult = true): FakeIssue {
  return {
    NewRecord: vi.fn(),
    Save: vi.fn(async () => saveResult),
    LatestResult: { CompleteMessage: 'err' },
  };
}

const BUG_TYPE = { ID: 'T-BUG', DefaultPriority: 'High' };
const ctx = {} as never;

beforeEach(() => {
  vi.clearAllMocks();
  engineState.defaultStatus = { ID: 'S-NEW' };
  engineState.statusById = new Map([
    ['S-NEW', { ID: 'S-NEW', IsTerminal: false }],
    ['S-PROG', { ID: 'S-PROG', IsTerminal: false }],
    ['S-CLOSED', { ID: 'S-CLOSED', IsTerminal: true }],
  ]);
  engineState.terminalStatuses = [...engineState.statusById.values()];
  engineState.typeById = new Map([['T-BUG', BUG_TYPE]]);
  engineState.typeByName = new Map([['bug', BUG_TYPE]]);
});

describe('IssueService.CreateIssue (thin wrapper)', () => {
  it('sets fields with defaulted status + type priority, then saves', async () => {
    const issue = makeFakeIssue();
    getEntityObjectMock.mockResolvedValueOnce(issue);

    const result = await new IssueService().CreateIssue({ Title: 'It broke', IssueTypeName: 'Bug' }, ctx);

    expect(result).toBe(issue);
    expect(issue.NewRecord).toHaveBeenCalledOnce();
    expect(issue.Title).toBe('It broke');
    expect(issue.IssueTypeID).toBe('T-BUG');
    expect(issue.StatusID).toBe('S-NEW'); // defaulted
    expect(issue.Priority).toBe('High'); // type default
    expect(issue.Save).toHaveBeenCalledOnce();
  });

  it('returns null and does not save when the IssueType cannot be resolved', async () => {
    const result = await new IssueService().CreateIssue({ Title: 'x', IssueTypeName: 'Nope' }, ctx);
    expect(result).toBeNull();
    expect(getEntityObjectMock).not.toHaveBeenCalled();
  });

  it('returns null when Save fails', async () => {
    const issue = makeFakeIssue(false);
    getEntityObjectMock.mockResolvedValueOnce(issue);
    const result = await new IssueService().CreateIssue({ Title: 'x', IssueTypeID: 'T-BUG' }, ctx);
    expect(result).toBeNull();
  });
});

describe('IssueService.TransitionStatus (thin wrapper)', () => {
  it('sets StatusID and saves on a real change', async () => {
    const issue = makeFakeIssue();
    issue.StatusID = 'S-PROG';
    const ok = await new IssueService().TransitionStatus(issue as never, 'S-CLOSED', ctx);
    expect(ok).toBe(true);
    expect(issue.StatusID).toBe('S-CLOSED');
    expect(issue.Save).toHaveBeenCalledOnce();
  });

  it('is a no-op when the status is unchanged', async () => {
    const issue = makeFakeIssue();
    issue.StatusID = 'S-PROG';
    const ok = await new IssueService().TransitionStatus(issue as never, 'S-PROG', ctx);
    expect(ok).toBe(true);
    expect(issue.Save).not.toHaveBeenCalled();
  });

  it('rejects an unknown status without saving', async () => {
    const issue = makeFakeIssue();
    issue.StatusID = 'S-NEW';
    const ok = await new IssueService().TransitionStatus(issue as never, 'S-MISSING', ctx);
    expect(ok).toBe(false);
    expect(issue.Save).not.toHaveBeenCalled();
  });
});

describe('IssueService.Assign (thin wrapper)', () => {
  it('sets the polymorphic assignee fields and saves', async () => {
    const issue = makeFakeIssue();
    const ok = await new IssueService().Assign(issue as never, 'ENT-1', 'REC-1', ctx);
    expect(ok).toBe(true);
    expect(issue.AssigneeEntityID).toBe('ENT-1');
    expect(issue.AssigneeRecordID).toBe('REC-1');
    expect(issue.Save).toHaveBeenCalledOnce();
  });
});

describe('IssueService.Close (thin wrapper)', () => {
  it('transitions to the first terminal status', async () => {
    const issue = makeFakeIssue();
    issue.StatusID = 'S-PROG';
    const ok = await new IssueService().Close(issue as never, ctx);
    expect(ok).toBe(true);
    expect(issue.StatusID).toBe('S-CLOSED'); // the IsTerminal status
    expect(issue.Save).toHaveBeenCalledOnce();
  });
});
