import { describe, it, expect, beforeEach } from 'vitest';

import { IssueEngine } from '../IssueEngine.js';

// ---------------------------------------------------------------------------
// IssueEngine's lookup methods are pure functions over its two cache arrays
// (_IssueTypes, _IssueStatuses). We populate those caches directly (the engine
// is a BaseSingleton, so we reach into the shared instance) and assert the
// lookups, ordering, and default/terminal helpers — no DB or provider needed.
// ---------------------------------------------------------------------------

interface FakeStatus {
  ID: string;
  Name: string;
  Sequence: number;
  IsDefault: boolean;
  IsTerminal: boolean;
}
interface FakeType {
  ID: string;
  Name: string;
  DefaultPriority: string;
}

const STATUSES: FakeStatus[] = [
  { ID: 'S-NEW', Name: 'New', Sequence: 10, IsDefault: true, IsTerminal: false },
  { ID: 'S-PROG', Name: 'In Progress', Sequence: 30, IsDefault: false, IsTerminal: false },
  { ID: 'S-CLOSED', Name: 'Closed', Sequence: 60, IsDefault: false, IsTerminal: true },
];
const TYPES: FakeType[] = [
  { ID: 'T-BUG', Name: 'Bug', DefaultPriority: 'High' },
  { ID: 'T-FEAT', Name: 'Feature Request', DefaultPriority: 'Medium' },
];

/** Reach into the singleton and set the private caches for testing. */
function seedEngine(): IssueEngine {
  const engine = IssueEngine.Instance;
  // The lookup methods only touch the cache arrays; we bypass Config() entirely.
  (engine as unknown as { _IssueStatuses: FakeStatus[] })._IssueStatuses = [...STATUSES];
  (engine as unknown as { _IssueTypes: FakeType[] })._IssueTypes = [...TYPES];
  return engine;
}

describe('IssueEngine lookups', () => {
  let engine: IssueEngine;
  beforeEach(() => {
    engine = seedEngine();
  });

  it('IssueTypeByName is case- and whitespace-insensitive', () => {
    expect(engine.IssueTypeByName('bug')?.ID).toBe('T-BUG');
    expect(engine.IssueTypeByName('  Feature Request ')?.ID).toBe('T-FEAT');
    expect(engine.IssueTypeByName('nope')).toBeUndefined();
  });

  it('IssueTypeByID resolves via UUID equality', () => {
    expect(engine.IssueTypeByID('T-BUG')?.Name).toBe('Bug');
    expect(engine.IssueTypeByID('missing')).toBeUndefined();
  });

  it('IssueStatusByName / ByID resolve correctly', () => {
    expect(engine.IssueStatusByName('In Progress')?.ID).toBe('S-PROG');
    expect(engine.IssueStatusByID('S-CLOSED')?.Name).toBe('Closed');
  });

  it('DefaultStatus returns the IsDefault row', () => {
    expect(engine.DefaultStatus?.ID).toBe('S-NEW');
  });

  it('OrderedStatuses sorts by Sequence ascending', () => {
    expect(engine.OrderedStatuses.map((s) => s.ID)).toEqual(['S-NEW', 'S-PROG', 'S-CLOSED']);
  });

  it('IsTerminalStatus reflects the IsTerminal flag', () => {
    expect(engine.IsTerminalStatus('S-CLOSED')).toBe(true);
    expect(engine.IsTerminalStatus('S-NEW')).toBe(false);
    expect(engine.IsTerminalStatus('unknown')).toBe(false);
  });
});
