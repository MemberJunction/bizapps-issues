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
const ISSUE_TYPES_ENTITY = 'MJ_BizApps_Issues: Issue Types';
const ISSUE_STATUS_ENTITY = 'MJ_BizApps_Issues: Issue Status';

@RegisterForStartup()
export class IssueEngine extends BaseEngine<IssueEngine> {
  public static get Instance(): IssueEngine {
    return super.getInstance<IssueEngine>();
  }

  private _activeProvider?: IMetadataProvider;
  private _IssueTypes: mjBizAppsIssuesIssueTypeEntity[] = [];
  private _IssueStatuses: mjBizAppsIssuesIssueStatusEntity[] = [];

  /**
   * Returns the active provider explicitly supplied to {@link Config}, falling back to
   * `BaseEngine`'s bound/global provider resolution.
   */
  public override get ProviderToUse(): IMetadataProvider {
    return this._activeProvider ?? super.ProviderToUse;
  }

  /**
   * Loads Issue Types and Issue Statuses into the in-memory cache. Lazy and idempotent —
   * callers invoke this at entry and it is a no-op once loaded unless `forceRefresh` is true
   * or the explicit provider changes.
   *
   * Both tables are global, non-RLS bounded lookup tables (`CacheLocal: true`).
   */
  public async Config(
    forceRefresh?: boolean,
    contextUser?: UserInfo,
    provider?: IMetadataProvider,
  ): Promise<void> {
    const providerChanged = Boolean(
      provider && this._activeProvider && provider !== this._activeProvider,
    );
    if (provider !== undefined) {
      this._activeProvider = provider;
    }

    const activeProvider = provider ?? this.ProviderToUse;
    const effectiveForceRefresh = Boolean(forceRefresh || providerChanged);
    const configs = this.buildPermittedConfigs(activeProvider, contextUser);

    await super.Load(configs, provider, effectiveForceRefresh, contextUser);
  }

  protected buildPermittedConfigs(
    provider: IMetadataProvider | undefined,
    contextUser: UserInfo | undefined,
  ): Partial<BaseEnginePropertyConfig>[] {
    const candidates: Array<{ EntityName: string; PropertyName: string; CacheLocal: boolean }> = [
      {
        EntityName: ISSUE_TYPES_ENTITY,
        PropertyName: '_IssueTypes',
        CacheLocal: true,
      },
      {
        EntityName: ISSUE_STATUS_ENTITY,
        PropertyName: '_IssueStatuses',
        CacheLocal: true,
      },
    ];

    const configs: Partial<BaseEnginePropertyConfig>[] = [];
    for (const candidate of candidates) {
      if (this.canReadEntity(candidate.EntityName, provider, contextUser)) {
        configs.push({
          Type: 'entity',
          EntityName: candidate.EntityName,
          PropertyName: candidate.PropertyName,
          CacheLocal: candidate.CacheLocal,
        });
      }
    }
    return configs;
  }

  protected canReadEntity(
    entityName: string,
    provider: IMetadataProvider | undefined,
    contextUser: UserInfo | undefined,
  ): boolean {
    const entities = provider?.Entities;
    if (!Array.isArray(entities) || entities.length === 0) {
      return true;
    }
    const entityInfo = provider?.EntityByName?.(entityName);
    if (!entityInfo) {
      return false;
    }
    const user = contextUser ?? provider?.CurrentUser;
    if (!user) {
      return true;
    }
    return entityInfo.GetUserPermisions(user)?.CanRead ?? false;
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

  /** Active Issue Types sorted alphabetically by Name. */
  public get ActiveIssueTypes(): mjBizAppsIssuesIssueTypeEntity[] {
    return this.IssueTypes
      .filter((t) => t.IsActive)
      .sort((a, b) => a.Name.localeCompare(b.Name));
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
