import { BaseEntity, BaseEntityEvent, EntitySaveOptions, LogError, UserInfo } from '@memberjunction/core';
import { RegisterClass } from '@memberjunction/global';
import { ActionEngineServer } from '@memberjunction/actions';
import { ActionParam } from '@memberjunction/actions-base';
import { mjBizAppsIssuesIssueEntity } from '@mj-biz-apps/issues-entities';
import { IssueEngine } from '@mj-biz-apps/issues-core';

import { SequenceService } from './SequenceService.js';

/**
 * Server-side subclass of {@link mjBizAppsIssuesIssueEntity}.
 *
 * Owns the SERVER-ONLY lifecycle side-effects that must fire on EVERY save path
 * (UI, API, automation) — not just when callers route through IssueService:
 *
 *   1. **IssueNumber assignment** (insert only) — via the atomic
 *      spAssignNextIssueNumber proc, before super.Save(); immutable thereafter.
 *   2. **Lifecycle timestamp stamping** (in Save(), before super.Save()) — when
 *      StatusID changes: stamp ResolvedAt on entering a Resolved/Terminal status,
 *      ClosedAt on entering a Terminal status, and clear them on reopen. These
 *      mutate the row being written, so they happen inline.
 *   3. **IssueType action hooks** (post-save, via RegisterEventHandler) — fire
 *      OnCreate (insert), OnStatusChange (+ OnClose on terminal), and OnAssign
 *      (assignee change) through the Action engine. These are decoupled reactions
 *      that must NOT be able to fail or slow the save, so they run after the save
 *      event finalizes — mirroring bizapps-tasks' TaskNotificationHandler and
 *      SaaS's OrganizationPersonRoleEntityServer event-handler pattern.
 *
 * Registered at priority 2 so this server subclass wins over the priority-1
 * client-shared entity.
 */
@RegisterClass(BaseEntity, 'MJ_BizApps_Issues: Issues', 2)
export class IssueEntityServer extends mjBizAppsIssuesIssueEntity {
  private _hookHandlerRegistered = false;

  public override async Save(options?: EntitySaveOptions): Promise<boolean> {
    this.ensureHookHandler();

    const isNew = !this.IsSaved;

    // Snapshot the status transition BEFORE super.Save() resets dirty flags.
    const statusField = this.GetFieldByName('StatusID');
    const statusChanged = statusField?.Dirty ?? false;
    const oldStatusID = (statusField?.OldValue as string | null) ?? null;

    const assigneeField = this.GetFieldByName('AssigneeRecordID');
    const assigneeEntityField = this.GetFieldByName('AssigneeEntityID');
    const assigneeChanged = (assigneeField?.Dirty ?? false) || (assigneeEntityField?.Dirty ?? false);

    // 1. IssueNumber (insert only, immutable)
    if (isNew && !this.IssueNumber) {
      await this.assignIssueNumber();
    }

    // 2. Lifecycle timestamps — stamp inline so they're part of this write.
    //    On insert, treat the initial status as "entered" too.
    if (statusChanged || isNew) {
      await this.stampLifecycleTimestamps();
    }

    // Stash what the post-save hook handler needs (dirty flags are gone after save).
    this._pendingHookContext = { isNew, statusChanged: statusChanged && !isNew, oldStatusID, assigneeChanged: assigneeChanged && !isNew };

    return super.Save(options);
  }

  // ------------------------------------------------------------------
  // 1. IssueNumber assignment
  // ------------------------------------------------------------------

  /** Allocates and sets IssueNumber for a new Issue based on its AppScope. */
  private async assignIssueNumber(): Promise<void> {
    try {
      this.IssueNumber = await SequenceService.assignNextIssueNumber(this.AppScope, this);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      LogError(`IssueEntityServer: failed to assign IssueNumber (AppScope=${this.AppScope ?? '(null)'}): ${msg}`);
      throw err;
    }
  }

  // ------------------------------------------------------------------
  // 2. Lifecycle timestamp stamping (inline, mutates the row)
  // ------------------------------------------------------------------

  /**
   * Stamps ResolvedAt / ClosedAt based on the NEW status's flags:
   *  - entering an IsResolved OR IsTerminal status → set ResolvedAt (if not already set)
   *  - entering an IsTerminal status → set ClosedAt
   *  - leaving into a non-terminal, non-resolved (active) status (reopen) → clear both
   * Loads the engine for the IsResolved/IsTerminal lookup.
   */
  private async stampLifecycleTimestamps(): Promise<void> {
    await IssueEngine.Instance.Config(false, this.ContextCurrentUser);

    const isResolved = IssueEngine.Instance.IsResolvedStatus(this.StatusID);
    const isTerminal = IssueEngine.Instance.IsTerminalStatus(this.StatusID);
    const now = new Date();

    if (isTerminal) {
      if (!this.ResolvedAt) {
        this.ResolvedAt = now;
      }
      this.ClosedAt = now;
    } else if (isResolved) {
      if (!this.ResolvedAt) {
        this.ResolvedAt = now;
      }
      // Resolved-but-not-closed: ensure not marked closed.
      this.ClosedAt = null;
    } else {
      // Active (reopened or never resolved): clear lifecycle stamps.
      this.ResolvedAt = null;
      this.ClosedAt = null;
    }
  }

  // ------------------------------------------------------------------
  // 3. Action hooks (post-save reaction via event handler)
  // ------------------------------------------------------------------

  private _pendingHookContext: HookContext | null = null;

  /**
   * Registers a per-instance save-event handler (once) that fires the IssueType
   * action hooks AFTER the save finalizes. Fire-and-forget; failures are logged,
   * never propagated — a misconfigured hook must not break the save.
   */
  private ensureHookHandler(): void {
    if (this._hookHandlerRegistered) {
      return;
    }
    this._hookHandlerRegistered = true;

    this.RegisterEventHandler((event: BaseEntityEvent) => {
      if (event.type !== 'save') {
        return;
      }
      const ctx = this._pendingHookContext;
      this._pendingHookContext = null;
      if (!ctx) {
        return;
      }
      this.fireLifecycleHooks(ctx).catch((err: unknown) => {
        const msg = err instanceof Error ? err.message : String(err);
        LogError(`IssueEntityServer: lifecycle hook firing failed for issue ${this.ID}: ${msg}`);
      });
    });
  }

  /** Dispatches the IssueType action hooks for the events that occurred this save. */
  private async fireLifecycleHooks(ctx: HookContext): Promise<void> {
    await IssueEngine.Instance.Config(false, this.ContextCurrentUser);
    const issueType = IssueEngine.Instance.IssueTypeByID(this.IssueTypeID);
    if (!issueType) {
      return;
    }

    if (ctx.isNew) {
      await this.fireHook(issueType.OnCreateActionID);
    }
    if (ctx.statusChanged) {
      await this.fireHook(issueType.OnStatusChangeActionID);
      if (IssueEngine.Instance.IsTerminalStatus(this.StatusID)) {
        await this.fireHook(issueType.OnCloseActionID);
      }
    }
    if (ctx.assigneeChanged) {
      await this.fireHook(issueType.OnAssignActionID);
    }
  }

  /**
   * Fires a single IssueType action hook by Action ID, passing the issue's identity
   * as input params. No-op when actionID is null. Failures are logged, not thrown.
   */
  private async fireHook(actionID: string | null): Promise<void> {
    if (!actionID) {
      return;
    }
    try {
      const contextUser: UserInfo | undefined = this.ContextCurrentUser;
      await ActionEngineServer.Instance.Config(false, contextUser);
      const action = ActionEngineServer.Instance.Actions.find((a) => a.ID === actionID);
      if (!action) {
        LogError(`IssueEntityServer.fireHook: Action ${actionID} not found`);
        return;
      }

      const params: ActionParam[] = [
        { Name: 'IssueID', Value: this.ID, Type: 'Input' },
        { Name: 'IssueNumber', Value: this.IssueNumber, Type: 'Input' },
        { Name: 'Title', Value: this.Title, Type: 'Input' },
        { Name: 'StatusID', Value: this.StatusID, Type: 'Input' },
        { Name: 'Priority', Value: this.Priority, Type: 'Input' },
        { Name: 'Severity', Value: this.Severity, Type: 'Input' },
      ];

      await ActionEngineServer.Instance.RunAction({
        Action: action,
        ContextUser: contextUser,
        Params: params,
        Filters: [],
      });
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      LogError(`IssueEntityServer.fireHook: failed to run Action ${actionID}: ${msg}`);
    }
  }
}

/** Snapshot of which lifecycle events occurred during a save, consumed post-save. */
interface HookContext {
  isNew: boolean;
  statusChanged: boolean;
  oldStatusID: string | null;
  assigneeChanged: boolean;
}
