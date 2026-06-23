import {
  BaseEngine,
  BaseEnginePropertyConfig,
  IMetadataProvider,
  RegisterForStartup,
  UserInfo,
} from '@memberjunction/core';
import { UUIDsEqual } from '@memberjunction/global';
import { Observable } from 'rxjs';

import {
  mjBizAppsIssuesIssueTypeEntity,
  mjBizAppsIssuesIssueStatusEntity,
} from '@mj-biz-apps/issues-entities';

/**
 * IssueEngine is a singleton engine providing centralized, cached, reactive access to the
 * BizApps Issues reference data: Issue Types and Issue Statuses. Both are small, unfiltered
 * lookup sets that drive issue classification and the workflow board, so they are fully
 * cached in memory.
 *
 * Mirrors the canonical MJ BaseEngine pattern (see ApplicationSettingEngine / UserInfoEngine):
 * the BaseEnginePropertyConfig entries auto-subscribe to BaseEntity events, so the caches stay
 * fresh on save/delete/remote-invalidate and the `$` observables re-emit automatically — no
 * hand-written invalidation.
 *
 * Usage:
 * ```typescript
 * const engine = IssueEngine.Instance;
 * await engine.Config(false, contextUser);          // lazy, no-op once loaded
 * const newStatus = engine.DefaultStatus;           // the IsDefault status
 * const bug = engine.IssueTypeByName('Bug');
 * ```
 */
@RegisterForStartup()
export class IssueEngine extends BaseEngine<IssueEngine> {
  public static get Instance(): IssueEngine {
    return super.getInstance<IssueEngine>();
  }

  private _IssueTypes: mjBizAppsIssuesIssueTypeEntity[] = [];
  private _IssueStatuses: mjBizAppsIssuesIssueStatusEntity[] = [];

  /**
   * Loads Issue Types and Issue Statuses into the in-memory cache. Lazy and idempotent —
   * callers invoke this at entry and it is a no-op once loaded.
   */
  public async Config(
    forceRefresh?: boolean,
    contextUser?: UserInfo,
    provider?: IMetadataProvider,
  ): Promise<void> {
    const configs: Partial<BaseEnginePropertyConfig>[] = [
      {
        Type: 'entity',
        EntityName: 'MJ_BizApps_Issues: Issue Types',
        PropertyName: '_IssueTypes',
        CacheLocal: true,
      },
      {
        Type: 'entity',
        EntityName: 'MJ_BizApps_Issues: Issue Status',
        PropertyName: '_IssueStatuses',
        CacheLocal: true,
      },
    ];

    await super.Load(configs, provider, forceRefresh, contextUser);
  }

  // ========================================================================
  // OBSERVABLE ACCESSORS
  // ========================================================================

  /** Observable stream of the cached Issue Types; re-emits on any change. */
  public get IssueTypes$(): Observable<mjBizAppsIssuesIssueTypeEntity[]> {
    return this.ObserveProperty<mjBizAppsIssuesIssueTypeEntity>('_IssueTypes');
  }

  /** Observable stream of the cached Issue Statuses; re-emits on any change. */
  public get IssueStatuses$(): Observable<mjBizAppsIssuesIssueStatusEntity[]> {
    return this.ObserveProperty<mjBizAppsIssuesIssueStatusEntity>('_IssueStatuses');
  }

  // ========================================================================
  // PUBLIC ACCESSORS
  // ========================================================================

  /** All cached Issue Types. */
  public get IssueTypes(): mjBizAppsIssuesIssueTypeEntity[] {
    return this._IssueTypes ?? [];
  }

  /** All cached Issue Statuses. */
  public get IssueStatuses(): mjBizAppsIssuesIssueStatusEntity[] {
    return this._IssueStatuses ?? [];
  }

  /** Issue Statuses ordered by Sequence (board column order). */
  public get OrderedStatuses(): mjBizAppsIssuesIssueStatusEntity[] {
    return [...this.IssueStatuses].sort((a, b) => a.Sequence - b.Sequence);
  }

  /** The default status applied to new issues (the IsDefault row), or undefined. */
  public get DefaultStatus(): mjBizAppsIssuesIssueStatusEntity | undefined {
    return this.IssueStatuses.find((s) => s.IsDefault);
  }

  /** Look up an Issue Type by ID. */
  public IssueTypeByID(id: string): mjBizAppsIssuesIssueTypeEntity | undefined {
    return this.IssueTypes.find((t) => UUIDsEqual(t.ID, id));
  }

  /** Look up an Issue Type by exact Name. */
  public IssueTypeByName(name: string): mjBizAppsIssuesIssueTypeEntity | undefined {
    const target = name.trim().toLowerCase();
    return this.IssueTypes.find((t) => t.Name.trim().toLowerCase() === target);
  }

  /** Look up an Issue Status by ID. */
  public IssueStatusByID(id: string): mjBizAppsIssuesIssueStatusEntity | undefined {
    return this.IssueStatuses.find((s) => UUIDsEqual(s.ID, id));
  }

  /** Look up an Issue Status by exact Name. */
  public IssueStatusByName(name: string): mjBizAppsIssuesIssueStatusEntity | undefined {
    const target = name.trim().toLowerCase();
    return this.IssueStatuses.find((s) => s.Name.trim().toLowerCase() === target);
  }

  /** True if the given status ID is a terminal (closed/end) state. */
  public IsTerminalStatus(statusID: string): boolean {
    return this.IssueStatusByID(statusID)?.IsTerminal ?? false;
  }

  /** True if the given status ID is the resolved-but-not-closed state. */
  public IsResolvedStatus(statusID: string): boolean {
    return this.IssueStatusByID(statusID)?.IsResolved ?? false;
  }
}
