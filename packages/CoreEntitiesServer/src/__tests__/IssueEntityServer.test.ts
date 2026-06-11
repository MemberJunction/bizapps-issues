import { describe, it, expect, beforeEach, vi } from 'vitest';

// ---------------------------------------------------------------------------
// IssueEntityServer.Save() assigns IssueNumber on insert (only when empty) via
// SequenceService, BEFORE delegating to the base entity's Save(). We mock:
//   - @mj-biz-apps/issues-entities  → a controllable base entity stub whose
//     Save() we can observe and whose IsSaved/IssueNumber/AppScope we set.
//   - ./SequenceService             → returns a deterministic number.
//   - @memberjunction/core / global → light stubs (RegisterClass is a no-op decorator).
// ---------------------------------------------------------------------------

const baseSaveMock = vi.fn(async () => true);

// Mutable state shared with the stub base so each test can configure it.
const baseState = {
  IsSaved: false,
  IssueNumber: null as string | null,
  AppScope: null as string | null,
};

vi.mock('@mj-biz-apps/issues-entities', () => {
  class StubIssueEntity {
    get IsSaved() { return baseState.IsSaved; }
    get IssueNumber() { return baseState.IssueNumber; }
    set IssueNumber(v: string | null) { baseState.IssueNumber = v; }
    get AppScope() { return baseState.AppScope; }
    async Save() { return baseSaveMock(); }
  }
  return { mjBizAppsIssuesIssueEntity: StubIssueEntity };
});

const assignMock = vi.fn(async () => 'MJC-1');
vi.mock('../SequenceService.js', () => ({
  SequenceService: { assignNextIssueNumber: (...a: unknown[]) => assignMock(...a) },
}));

vi.mock('@memberjunction/core', () => ({
  BaseEntity: class {},
  LogError: vi.fn(),
}));
vi.mock('@memberjunction/global', () => ({
  // RegisterClass is a decorator factory; return a no-op decorator.
  RegisterClass: () => (_target: unknown) => _target,
}));

import { IssueEntityServer } from '../IssueEntityServer.js';

beforeEach(() => {
  vi.clearAllMocks();
  baseState.IsSaved = false;
  baseState.IssueNumber = null;
  baseState.AppScope = null;
  assignMock.mockResolvedValue('MJC-1');
});

describe('IssueEntityServer.Save', () => {
  it('assigns IssueNumber from SequenceService on insert when empty, then saves', async () => {
    baseState.IsSaved = false;
    baseState.AppScope = 'MJC';
    const e = new IssueEntityServer();

    const ok = await e.Save();

    expect(ok).toBe(true);
    expect(assignMock).toHaveBeenCalledOnce();
    expect(assignMock).toHaveBeenCalledWith('MJC', e); // passes AppScope + the entity (provider source)
    expect(baseState.IssueNumber).toBe('MJC-1');
    expect(baseSaveMock).toHaveBeenCalledOnce();
  });

  it('passes null AppScope through (proc defaults it to ISS)', async () => {
    baseState.IsSaved = false;
    baseState.AppScope = null;
    assignMock.mockResolvedValue('ISS-1');
    const e = new IssueEntityServer();

    await e.Save();

    expect(assignMock).toHaveBeenCalledWith(null, e);
    expect(baseState.IssueNumber).toBe('ISS-1');
  });

  it('does NOT assign on update (already saved) — immutable', async () => {
    baseState.IsSaved = true;
    baseState.IssueNumber = 'MJC-7';
    const e = new IssueEntityServer();

    await e.Save();

    expect(assignMock).not.toHaveBeenCalled();
    expect(baseState.IssueNumber).toBe('MJC-7'); // unchanged
    expect(baseSaveMock).toHaveBeenCalledOnce();
  });

  it('does NOT reassign on insert when IssueNumber is already set', async () => {
    baseState.IsSaved = false;
    baseState.IssueNumber = 'PREASSIGNED-99';
    const e = new IssueEntityServer();

    await e.Save();

    expect(assignMock).not.toHaveBeenCalled();
    expect(baseState.IssueNumber).toBe('PREASSIGNED-99');
  });

  it('propagates allocation failure (does not save a numberless issue)', async () => {
    baseState.IsSaved = false;
    assignMock.mockRejectedValueOnce(new Error('proc failed'));
    const e = new IssueEntityServer();

    await expect(e.Save()).rejects.toThrow('proc failed');
    expect(baseSaveMock).not.toHaveBeenCalled();
  });
});
