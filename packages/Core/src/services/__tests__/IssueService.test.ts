import { describe, it, expect, beforeEach, vi } from 'vitest';

// ---------------------------------------------------------------------------
// IssueService uses:
//   - new Metadata().GetEntityObject(name, user) → entity w/ typed props + Save()
//   - IssueEngine.Instance (Config + lookups + DefaultStatus)
//   - ActionEngineServer.Instance (Config + Actions + RunAction) for hook firing
// We mock all three so the service logic runs in isolation. Fake entities expose
// plain writable properties (the service assigns typed props, not .Set()).
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

const runActionMock = vi.fn();
const actionsList: Array<{ ID: string }> = [{ ID: 'ACT-CREATE' }, { ID: 'ACT-STATUS' }, { ID: 'ACT-CLOSE' }];
vi.mock('@memberjunction/actions', () => ({
  ActionEngineServer: {
    Instance: {
      Config: vi.fn(async () => undefined),
      get Actions() {
        return actionsList;
      },
      RunAction: (...args: unknown[]) => runActionMock(...args),
    },
  },
}));
vi.mock('@memberjunction/actions-base', () => ({ ActionParam: class {} }));

// IssueEngine is mocked: the service only calls Config() + a few lookups.
const engineState = {
  defaultStatus: { ID: 'S-NEW', IsTerminal: false } as { ID: string; IsTerminal: boolean } | undefined,
  statusById: new Map<string, { ID: string; IsTerminal: boolean }>(),
  typeById: new Map<string, { ID: string; DefaultPriority: string; OnCreateActionID: string | null; OnStatusChangeActionID: string | null; OnCloseActionID: string | null; OnAssignActionID: string | null }>(),
  typeByName: new Map<string, { ID: string; DefaultPriority: string; OnCreateActionID: string | null; OnStatusChangeActionID: string | null; OnCloseActionID: string | null; OnAssignActionID: string | null }>(),
  terminalStatuses: [] as { ID: string; IsTerminal: boolean }[],
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
      IssueTypeByName: (name: string) => engineState.typeByName.get(name.trim().toLowerCase()),
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

const BUG_TYPE = {
  ID: 'T-BUG',
  DefaultPriority: 'High',
  OnCreateActionID: 'ACT-CREATE',
  OnStatusChangeActionID: 'ACT-STATUS',
  OnCloseActionID: 'ACT-CLOSE',
  OnAssignActionID: null,
};

beforeEach(() => {
  vi.clearAllMocks();
  engineState.defaultStatus = { ID: 'S-NEW', IsTerminal: false };
  engineState.statusById = new Map([
    ['S-NEW', { ID: 'S-NEW', IsTerminal: false }],
    ['S-PROG', { ID: 'S-PROG', IsTerminal: false }],
    ['S-CLOSED', { ID: 'S-CLOSED', IsTerminal: true }],
  ]);
  engineState.terminalStatuses = [...engineState.statusById.values()];
  engineState.typeById = new Map([['T-BUG', BUG_TYPE]]);
  engineState.typeByName = new Map([['bug', BUG_TYPE]]);
});

const ctx = {} as never;

describe('IssueService.CreateIssue', () => {
  it('defaults status to DefaultStatus and priority to the type default, then fires OnCreate', async () => {
    const issue = makeFakeIssue();
    getEntityObjectMock.mockResolvedValueOnce(issue);

    const result = await new IssueService().CreateIssue({ Title: 'It broke', IssueTypeName: 'Bug' }, ctx);

    expect(result).toBe(issue);
    expect(issue.NewRecord).toHaveBeenCalledOnce();
    expect(issue.Title).toBe('It broke');
    expect(issue.IssueTypeID).toBe('T-BUG');
    expect(issue.StatusID).toBe('S-NEW'); // default status
    expect(issue.Priority).toBe('High'); // type's DefaultPriority
    expect(issue.Save).toHaveBeenCalledOnce();
    expect(runActionMock).toHaveBeenCalledOnce(); // OnCreate hook fired
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
    expect(runActionMock).not.toHaveBeenCalled(); // hook not fired on failed save
  });
});

describe('IssueService.TransitionStatus', () => {
  it('stamps ClosedAt + ResolvedAt and fires OnStatusChange + OnClose on terminal transition', async () => {
    const issue = makeFakeIssue();
    issue.StatusID = 'S-PROG';
    issue.IssueTypeID = 'T-BUG';

    const ok = await new IssueService().TransitionStatus(issue as never, 'S-CLOSED', ctx);

    expect(ok).toBe(true);
    expect(issue.StatusID).toBe('S-CLOSED');
    expect(issue.ClosedAt).toBeInstanceOf(Date);
    expect(issue.ResolvedAt).toBeInstanceOf(Date);
    expect(runActionMock).toHaveBeenCalledTimes(2); // OnStatusChange + OnClose
  });

  it('is a no-op when the status is unchanged', async () => {
    const issue = makeFakeIssue();
    issue.StatusID = 'S-PROG';
    const ok = await new IssueService().TransitionStatus(issue as never, 'S-PROG', ctx);
    expect(ok).toBe(true);
    expect(issue.Save).not.toHaveBeenCalled();
  });

  it('non-terminal transition fires only OnStatusChange and clears ClosedAt', async () => {
    const issue = makeFakeIssue();
    issue.StatusID = 'S-NEW';
    issue.IssueTypeID = 'T-BUG';
    const ok = await new IssueService().TransitionStatus(issue as never, 'S-PROG', ctx);
    expect(ok).toBe(true);
    expect(issue.ClosedAt).toBeNull();
    expect(runActionMock).toHaveBeenCalledTimes(1); // OnStatusChange only
  });
});
