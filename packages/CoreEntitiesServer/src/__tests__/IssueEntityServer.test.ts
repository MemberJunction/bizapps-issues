import { describe, it, expect, beforeEach, vi } from 'vitest';

// ---------------------------------------------------------------------------
// IssueEntityServer.Save() now owns three lifecycle concerns:
//   1. IssueNumber assignment on insert (via SequenceService) — pre-save.
//   2. ResolvedAt/ClosedAt stamping on StatusID change — pre-save, inline.
//   3. IssueType action-hook firing (OnCreate/OnStatusChange/OnClose/OnAssign)
//      via RegisterEventHandler('save') — post-save reaction.
//
// We mock the base entity (a controllable stub exposing settable fields, a
// configurable GetFieldByName dirty/old, and a RegisterEventHandler we can fire),
// SequenceService, IssueEngine (status flag + type lookups), ActionEngineServer
// (records RunAction calls), and core/global stubs.
// ---------------------------------------------------------------------------

const baseSaveMock = vi.fn(async () => true);

// Field dirty/old config the stub's GetFieldByName returns, keyed by field name.
type FieldInfo = { Dirty: boolean; OldValue: unknown };
const fieldInfo: Record<string, FieldInfo> = {};

// Captured save-event handler (RegisterEventHandler) so tests can fire it.
let savedHandler: ((event: { type: string }) => void) | null = null;

const baseState = {
  IsSaved: false,
  IssueNumber: null as string | null,
  AppScope: null as string | null,
  StatusID: '',
  IssueTypeID: 'T-BUG',
  ResolvedAt: null as Date | null,
  ClosedAt: null as Date | null,
  AssigneeEntityID: null as string | null,
  AssigneeRecordID: null as string | null,
  Title: 'T',
  Priority: 'Medium',
  Severity: 'Medium',
  ID: 'ISS-X',
  ContextCurrentUser: {} as unknown,
};

vi.mock('@mj-biz-apps/issues-entities', () => {
  class StubIssueEntity {
    get IsSaved() { return baseState.IsSaved; }
    get IssueNumber() { return baseState.IssueNumber; }
    set IssueNumber(v: string | null) { baseState.IssueNumber = v; }
    get AppScope() { return baseState.AppScope; }
    get StatusID() { return baseState.StatusID; }
    get IssueTypeID() { return baseState.IssueTypeID; }
    get ResolvedAt() { return baseState.ResolvedAt; }
    set ResolvedAt(v: Date | null) { baseState.ResolvedAt = v; }
    get ClosedAt() { return baseState.ClosedAt; }
    set ClosedAt(v: Date | null) { baseState.ClosedAt = v; }
    get ID() { return baseState.ID; }
    get Title() { return baseState.Title; }
    get Priority() { return baseState.Priority; }
    get Severity() { return baseState.Severity; }
    get ContextCurrentUser() { return baseState.ContextCurrentUser; }
    GetFieldByName(name: string) { return fieldInfo[name] ?? { Dirty: false, OldValue: null }; }
    RegisterEventHandler(h: (event: { type: string }) => void) { savedHandler = h; }
    async Save() { return baseSaveMock(); }
  }
  return { mjBizAppsIssuesIssueEntity: StubIssueEntity };
});

const assignMock = vi.fn(async () => 'MJC-1');
vi.mock('../SequenceService.js', () => ({
  SequenceService: { assignNextIssueNumber: (...a: unknown[]) => assignMock(...a) },
}));

// IssueEngine: status flags + type (with On*ActionID) lookups.
const engine = {
  resolved: new Set<string>(),
  terminal: new Set<string>(),
  type: { ID: 'T-BUG', OnCreateActionID: 'ACT-CREATE', OnStatusChangeActionID: 'ACT-STATUS', OnCloseActionID: 'ACT-CLOSE', OnAssignActionID: 'ACT-ASSIGN' } as Record<string, string | null>,
};
vi.mock('@mj-biz-apps/issues-core', () => ({
  IssueEngine: {
    Instance: {
      Config: vi.fn(async () => undefined),
      IsResolvedStatus: (id: string) => engine.resolved.has(id),
      IsTerminalStatus: (id: string) => engine.terminal.has(id),
      IssueTypeByID: (_id: string) => engine.type,
    },
  },
}));

const runActionMock = vi.fn(async () => undefined);
vi.mock('@memberjunction/actions', () => ({
  ActionEngineServer: {
    Instance: {
      Config: vi.fn(async () => undefined),
      get Actions() {
        return [{ ID: 'ACT-CREATE' }, { ID: 'ACT-STATUS' }, { ID: 'ACT-CLOSE' }, { ID: 'ACT-ASSIGN' }];
      },
      RunAction: (...a: unknown[]) => runActionMock(...a),
    },
  },
}));
vi.mock('@memberjunction/actions-base', () => ({ ActionParam: class {} }));

vi.mock('@memberjunction/core', () => ({
  BaseEntity: class {},
  LogError: vi.fn(),
}));
vi.mock('@memberjunction/global', () => ({
  RegisterClass: () => (_t: unknown) => _t,
}));

import { IssueEntityServer } from '../IssueEntityServer.js';

/** Fire the captured post-save 'save' event handler (and let its async work settle). */
async function fireSaveEvent(): Promise<void> {
  savedHandler?.({ type: 'save' });
  await new Promise((r) => setTimeout(r, 0));
}

beforeEach(() => {
  vi.clearAllMocks();
  savedHandler = null;
  for (const k of Object.keys(fieldInfo)) delete fieldInfo[k];
  Object.assign(baseState, {
    IsSaved: false, IssueNumber: null, AppScope: null, StatusID: 'S-NEW',
    IssueTypeID: 'T-BUG', ResolvedAt: null, ClosedAt: null,
    AssigneeEntityID: null, AssigneeRecordID: null,
  });
  engine.resolved = new Set(['S-RESOLVED']);
  engine.terminal = new Set(['S-CLOSED']);
  engine.type = { ID: 'T-BUG', OnCreateActionID: 'ACT-CREATE', OnStatusChangeActionID: 'ACT-STATUS', OnCloseActionID: 'ACT-CLOSE', OnAssignActionID: 'ACT-ASSIGN' };
  assignMock.mockResolvedValue('MJC-1');
});

// ─── 1. IssueNumber (unchanged behavior) ──────────────────────────────────────
describe('IssueEntityServer — IssueNumber', () => {
  it('assigns on insert when empty, then saves', async () => {
    baseState.AppScope = 'MJC';
    const e = new IssueEntityServer();
    const ok = await e.Save();
    expect(ok).toBe(true);
    expect(assignMock).toHaveBeenCalledWith('MJC', e);
    expect(baseState.IssueNumber).toBe('MJC-1');
    expect(baseSaveMock).toHaveBeenCalledOnce();
  });

  it('does not assign on update (immutable)', async () => {
    baseState.IsSaved = true;
    baseState.IssueNumber = 'MJC-7';
    await new IssueEntityServer().Save();
    expect(assignMock).not.toHaveBeenCalled();
    expect(baseState.IssueNumber).toBe('MJC-7');
  });
});

// ─── 2. Lifecycle timestamp stamping ──────────────────────────────────────────
describe('IssueEntityServer — timestamp stamping', () => {
  it('stamps ResolvedAt + ClosedAt when transitioning into a terminal status', async () => {
    baseState.IsSaved = true;
    baseState.StatusID = 'S-CLOSED';
    fieldInfo['StatusID'] = { Dirty: true, OldValue: 'S-PROG' };
    await new IssueEntityServer().Save();
    expect(baseState.ResolvedAt).toBeInstanceOf(Date);
    expect(baseState.ClosedAt).toBeInstanceOf(Date);
  });

  it('stamps ResolvedAt but NOT ClosedAt when entering a resolved (non-terminal) status', async () => {
    baseState.IsSaved = true;
    baseState.StatusID = 'S-RESOLVED';
    fieldInfo['StatusID'] = { Dirty: true, OldValue: 'S-PROG' };
    await new IssueEntityServer().Save();
    expect(baseState.ResolvedAt).toBeInstanceOf(Date);
    expect(baseState.ClosedAt).toBeNull();
  });

  it('clears ResolvedAt + ClosedAt on reopen to an active status', async () => {
    baseState.IsSaved = true;
    baseState.StatusID = 'S-PROG'; // active (not resolved, not terminal)
    baseState.ResolvedAt = new Date();
    baseState.ClosedAt = new Date();
    fieldInfo['StatusID'] = { Dirty: true, OldValue: 'S-CLOSED' };
    await new IssueEntityServer().Save();
    expect(baseState.ResolvedAt).toBeNull();
    expect(baseState.ClosedAt).toBeNull();
  });

  it('does not stamp when StatusID is unchanged on update', async () => {
    baseState.IsSaved = true;
    baseState.StatusID = 'S-CLOSED';
    fieldInfo['StatusID'] = { Dirty: false, OldValue: 'S-CLOSED' };
    await new IssueEntityServer().Save();
    expect(baseState.ResolvedAt).toBeNull();
    expect(baseState.ClosedAt).toBeNull();
  });
});

// ─── 3. Action-hook firing (post-save event) ──────────────────────────────────
describe('IssueEntityServer — action hooks (post-save event)', () => {
  it('fires OnCreate on insert', async () => {
    baseState.StatusID = 'S-NEW';
    await new IssueEntityServer().Save();
    await fireSaveEvent();
    const actions = runActionMock.mock.calls.map((c) => (c[0] as { Action: { ID: string } }).Action.ID);
    expect(actions).toEqual(['ACT-CREATE']);
  });

  it('fires OnStatusChange + OnClose on a terminal status change (update)', async () => {
    baseState.IsSaved = true;
    baseState.StatusID = 'S-CLOSED';
    fieldInfo['StatusID'] = { Dirty: true, OldValue: 'S-PROG' };
    await new IssueEntityServer().Save();
    await fireSaveEvent();
    const actions = runActionMock.mock.calls.map((c) => (c[0] as { Action: { ID: string } }).Action.ID);
    expect(actions).toEqual(['ACT-STATUS', 'ACT-CLOSE']);
  });

  it('fires OnStatusChange only (no OnClose) on a non-terminal status change', async () => {
    baseState.IsSaved = true;
    baseState.StatusID = 'S-RESOLVED';
    fieldInfo['StatusID'] = { Dirty: true, OldValue: 'S-PROG' };
    await new IssueEntityServer().Save();
    await fireSaveEvent();
    const actions = runActionMock.mock.calls.map((c) => (c[0] as { Action: { ID: string } }).Action.ID);
    expect(actions).toEqual(['ACT-STATUS']);
  });

  it('fires OnAssign when the assignee changes on update', async () => {
    baseState.IsSaved = true;
    baseState.StatusID = 'S-PROG';
    fieldInfo['AssigneeRecordID'] = { Dirty: true, OldValue: null };
    await new IssueEntityServer().Save();
    await fireSaveEvent();
    const actions = runActionMock.mock.calls.map((c) => (c[0] as { Action: { ID: string } }).Action.ID);
    expect(actions).toEqual(['ACT-ASSIGN']);
  });

  it('does not throw if a hook Action is missing / RunAction fails', async () => {
    baseState.StatusID = 'S-NEW';
    runActionMock.mockRejectedValueOnce(new Error('action boom'));
    await new IssueEntityServer().Save();
    await expect(fireSaveEvent()).resolves.toBeUndefined(); // logged, not thrown
  });
});
