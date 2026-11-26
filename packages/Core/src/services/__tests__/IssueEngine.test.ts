import { describe, it, expect, beforeEach, vi } from 'vitest';
import { BaseEngine, type BaseEnginePropertyConfig, type IMetadataProvider, type UserInfo } from '@memberjunction/core';
import {
  IssueEngineBase,
  type mjBizAppsIssuesIssueStatusEntity,
  type mjBizAppsIssuesIssueTypeEntity,
} from '@mj-biz-apps/issues-entities';

import { IssueEngine } from '../IssueEngine.js';

interface TestStatusRow {
  ID: string;
  Name: string;
  Sequence: number;
  IsDefault: boolean;
  IsTerminal: boolean;
  IsResolved: boolean;
}

interface TestTypeRow {
  ID: string;
  Name: string;
  DefaultPriority: mjBizAppsIssuesIssueTypeEntity['DefaultPriority'];
  IsActive: boolean;
}

interface EngineCacheBacking {
  _IssueStatuses: mjBizAppsIssuesIssueStatusEntity[];
  _IssueTypes: mjBizAppsIssuesIssueTypeEntity[];
  _activeProvider?: IMetadataProvider;
}

const STATUSES: TestStatusRow[] = [
  { ID: 'S-PROG', Name: 'In Progress', Sequence: 30, IsDefault: false, IsTerminal: false, IsResolved: false },
  { ID: 'S-NEW', Name: 'New', Sequence: 10, IsDefault: true, IsTerminal: false, IsResolved: false },
  { ID: 'S-RES', Name: 'Resolved', Sequence: 50, IsDefault: false, IsTerminal: false, IsResolved: true },
  { ID: 'S-CLOSED', Name: 'Closed', Sequence: 60, IsDefault: false, IsTerminal: true, IsResolved: false },
];

const TYPES: TestTypeRow[] = [
  { ID: 'T-FEAT', Name: 'Feature Request', DefaultPriority: 'Medium', IsActive: true },
  { ID: 'T-BUG', Name: 'Bug', DefaultPriority: 'High', IsActive: true },
  { ID: 'T-ARCH', Name: 'Archived Type', DefaultPriority: 'Low', IsActive: false },
];

function asStatusEntities(rows: TestStatusRow[]): mjBizAppsIssuesIssueStatusEntity[] {
  return rows.map((row) => Object.assign(Object.create(null), row));
}

function asTypeEntities(rows: TestTypeRow[]): mjBizAppsIssuesIssueTypeEntity[] {
  return rows.map((row) => Object.assign(Object.create(null), row));
}

function seedEngineCache(engine: IssueEngine | IssueEngineBase): void {
  const backing = engine as object as EngineCacheBacking;
  backing._IssueStatuses = asStatusEntities(STATUSES);
  backing._IssueTypes = asTypeEntities(TYPES);
  backing._activeProvider = undefined;
}

function createMockProvider(readableEntities: Set<string>, userId: string): IMetadataProvider {
  const user = { ID: userId } as UserInfo;
  const entityEntries = ['MJ_BizApps_Issues: Issue Types', 'MJ_BizApps_Issues: Issue Status'].map(
    (name) => ({
      Name: name,
      GetUserPermisions: (_u: UserInfo) => ({ CanRead: readableEntities.has(name) }),
    }),
  );

  return {
    CurrentUser: user,
    Entities: entityEntries,
    EntityByName: (name: string) => entityEntries.find((e) => e.Name === name),
  } as object as IMetadataProvider;
}

describe('IssueEngine lookups', () => {
  let engine: IssueEngine;
  beforeEach(() => {
    engine = IssueEngine.Instance;
    seedEngineCache(engine);
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

  it('ActiveIssueTypes filters out inactive types and sorts by Name', () => {
    expect(engine.ActiveIssueTypes.map((t) => t.ID)).toEqual(['T-BUG', 'T-FEAT']);
  });

  it('IssueStatusByName / ByID resolve correctly', () => {
    expect(engine.IssueStatusByName('In Progress')?.ID).toBe('S-PROG');
    expect(engine.IssueStatusByID('S-CLOSED')?.Name).toBe('Closed');
  });

  it('DefaultStatus returns the IsDefault row', () => {
    expect(engine.DefaultStatus?.ID).toBe('S-NEW');
  });

  it('OrderedStatuses sorts by Sequence ascending', () => {
    expect(engine.OrderedStatuses.map((s) => s.ID)).toEqual(['S-NEW', 'S-PROG', 'S-RES', 'S-CLOSED']);
  });

  it('IsTerminalStatus and IsResolvedStatus reflect status flags', () => {
    expect(engine.IsTerminalStatus('S-CLOSED')).toBe(true);
    expect(engine.IsTerminalStatus('S-NEW')).toBe(false);
    expect(engine.IsTerminalStatus('unknown')).toBe(false);
    expect(engine.IsResolvedStatus('S-RES')).toBe(true);
    expect(engine.IsResolvedStatus('S-NEW')).toBe(false);
  });
});

describe('IssueEngine & IssueEngineBase multi-provider & CanRead safety', () => {
  const engines: Array<{ label: string; getEngine: () => IssueEngine | IssueEngineBase }> = [
    { label: 'IssueEngine', getEngine: () => IssueEngine.Instance },
    { label: 'IssueEngineBase', getEngine: () => IssueEngineBase.Instance },
  ];

  for (const { label, getEngine } of engines) {
    describe(label, () => {
      beforeEach(() => {
        vi.restoreAllMocks();
        seedEngineCache(getEngine());
      });

      it('overrides ProviderToUse with active provider and forces refresh when switching providers', async () => {
        const engine = getEngine();
        const calls: Array<{
          configs: Partial<BaseEnginePropertyConfig>[];
          provider: IMetadataProvider | undefined;
          forceRefresh: boolean;
        }> = [];

        vi.spyOn(BaseEngine.prototype as object as { Load: (...args: never[]) => Promise<void> }, 'Load')
          .mockImplementation(async (
            configs: Partial<BaseEnginePropertyConfig>[],
            provider: IMetadataProvider | undefined,
            forceRefresh?: boolean,
          ) => {
            calls.push({ configs, provider, forceRefresh: Boolean(forceRefresh) });
          });

        const providerA = createMockProvider(
          new Set(['MJ_BizApps_Issues: Issue Types', 'MJ_BizApps_Issues: Issue Status']),
          'user-a',
        );
        const providerB = createMockProvider(
          new Set(['MJ_BizApps_Issues: Issue Types', 'MJ_BizApps_Issues: Issue Status']),
          'user-b',
        );

        await engine.Config(false, providerA.CurrentUser, providerA);
        expect(engine.ProviderToUse).toBe(providerA);
        expect(calls[0].provider).toBe(providerA);
        expect(calls[0].forceRefresh).toBe(false);
        expect(calls[0].configs.every((c) => c.CacheLocal === true)).toBe(true);

        // Switching to a different provider forces a refresh and updates ProviderToUse
        await engine.Config(false, providerB.CurrentUser, providerB);
        expect(engine.ProviderToUse).toBe(providerB);
        expect(calls[1].provider).toBe(providerB);
        expect(calls[1].forceRefresh).toBe(true);
      });

      it('gates configured entities on CanRead so denied entities are skipped', async () => {
        const engine = getEngine();
        let capturedConfigs: Partial<BaseEnginePropertyConfig>[] = [];

        vi.spyOn(BaseEngine.prototype as object as { Load: (...args: never[]) => Promise<void> }, 'Load')
          .mockImplementation(async (configs: Partial<BaseEnginePropertyConfig>[]) => {
            capturedConfigs = configs;
          });

        const restrictedProvider = createMockProvider(
          new Set(['MJ_BizApps_Issues: Issue Status']),
          'restricted-user',
        );

        await engine.Config(true, restrictedProvider.CurrentUser, restrictedProvider);
        expect(capturedConfigs.map((c) => c.EntityName)).toEqual(['MJ_BizApps_Issues: Issue Status']);
      });

      it('passes undefined provider unchanged when caller omits provider', async () => {
        const engine = getEngine();
        let capturedProvider: IMetadataProvider | undefined = createMockProvider(new Set(), 'sentinel');

        vi.spyOn(BaseEngine.prototype as object as { Load: (...args: never[]) => Promise<void> }, 'Load')
          .mockImplementation(async (
            _configs: Partial<BaseEnginePropertyConfig>[],
            provider: IMetadataProvider | undefined,
          ) => {
            capturedProvider = provider;
          });

        await engine.Config(false);
        expect(capturedProvider).toBeUndefined();
      });
    });
  }
});
