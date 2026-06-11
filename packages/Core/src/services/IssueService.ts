import { Metadata, UserInfo, LogError } from '@memberjunction/core';
import { ActionEngineServer } from '@memberjunction/actions';
import { ActionParam } from '@memberjunction/actions-base';

import {
  mjBizAppsIssuesIssueEntity,
  mjBizAppsIssuesIssueTypeEntity,
} from '@mj-biz-apps/issues-entities';

import { IssueEngine } from './IssueEngine.js';

/** Severity / Priority enum shared by Issue and IssueType. */
export type IssuePriority = 'Low' | 'Medium' | 'High' | 'Critical';

/** Parameters for creating a new Issue. */
export interface CreateIssueParams {
  Title: string;
  Description?: string | null;
  /** IssueType — by ID or Name. If omitted, the caller must supply IssueTypeID. */
  IssueTypeID?: string;
  IssueTypeName?: string;
  /** Optional explicit status; defaults to the IsDefault status when omitted. */
  StatusID?: string;
  Severity?: IssuePriority;
  /** Defaults to the IssueType's DefaultPriority when omitted. */
  Priority?: IssuePriority;
  ReporterPersonID?: string | null;
  ReporterEmail?: string | null;
  SourceEntityID?: string | null;
  SourceRecordID?: string | null;
  AppScope?: string | null;
  CreatedByPersonID?: string | null;
}

/**
 * Core issue lifecycle service: create, transition status, assign, and close. All mutations go
 * through the MJ entity API so entity-subclass validation fires, and each lifecycle event fires
 * the matching IssueType action hook (OnCreate / OnStatusChange / OnAssign / OnClose) via the
 * Action engine — mirroring the bizapps-tasks TaskType action-hook mechanism, but strongly typed.
 *
 * Server-side: always pass contextUser.
 */
export class IssueService {
  /**
   * Creates a new Issue. Resolves the IssueType (by ID or name), defaults status to the
   * IsDefault status and priority to the type's DefaultPriority, saves, then fires the type's
   * OnCreate action hook. Returns the saved entity, or null on failure (details logged).
   */
  public async CreateIssue(
    params: CreateIssueParams,
    contextUser: UserInfo,
  ): Promise<mjBizAppsIssuesIssueEntity | null> {
    await IssueEngine.Instance.Config(false, contextUser);

    const issueType = this.resolveIssueType(params);
    if (!issueType) {
      LogError(`IssueService.CreateIssue: could not resolve IssueType (ID=${params.IssueTypeID}, Name=${params.IssueTypeName})`);
      return null;
    }

    const statusID = params.StatusID ?? IssueEngine.Instance.DefaultStatus?.ID;
    if (!statusID) {
      LogError('IssueService.CreateIssue: no StatusID provided and no default IssueStatus is configured');
      return null;
    }

    const md = new Metadata();
    const issue = await md.GetEntityObject<mjBizAppsIssuesIssueEntity>('MJ_BizApps_Issues: Issues', contextUser);
    issue.NewRecord();
    issue.Title = params.Title;
    issue.Description = params.Description ?? null;
    issue.IssueTypeID = issueType.ID;
    issue.StatusID = statusID;
    issue.Severity = params.Severity ?? 'Medium';
    issue.Priority = params.Priority ?? (issueType.DefaultPriority as IssuePriority);
    issue.ReporterPersonID = params.ReporterPersonID ?? null;
    issue.ReporterEmail = params.ReporterEmail ?? null;
    issue.SourceEntityID = params.SourceEntityID ?? null;
    issue.SourceRecordID = params.SourceRecordID ?? null;
    issue.AppScope = params.AppScope ?? null;
    issue.CreatedByPersonID = params.CreatedByPersonID ?? null;

    if (!(await issue.Save())) {
      LogError(`IssueService.CreateIssue: save failed: ${issue.LatestResult?.CompleteMessage ?? 'unknown error'}`);
      return null;
    }

    await this.fireHook(issueType.OnCreateActionID, issue, contextUser);
    return issue;
  }

  /**
   * Transitions an issue to a new status. Stamps ResolvedAt/ClosedAt as appropriate, saves, and
   * fires OnStatusChange (and OnClose when moving into a terminal status). Returns true on success.
   */
  public async TransitionStatus(
    issue: mjBizAppsIssuesIssueEntity,
    newStatusID: string,
    contextUser: UserInfo,
  ): Promise<boolean> {
    await IssueEngine.Instance.Config(false, contextUser);

    const newStatus = IssueEngine.Instance.IssueStatusByID(newStatusID);
    if (!newStatus) {
      LogError(`IssueService.TransitionStatus: unknown status ID ${newStatusID}`);
      return false;
    }
    if (issue.StatusID === newStatusID) {
      return true; // no-op
    }

    issue.StatusID = newStatusID;
    this.stampLifecycleTimestamps(issue, newStatus.IsTerminal);

    if (!(await issue.Save())) {
      LogError(`IssueService.TransitionStatus: save failed: ${issue.LatestResult?.CompleteMessage ?? 'unknown error'}`);
      return false;
    }

    const issueType = IssueEngine.Instance.IssueTypeByID(issue.IssueTypeID);
    await this.fireHook(issueType?.OnStatusChangeActionID, issue, contextUser);
    if (newStatus.IsTerminal) {
      await this.fireHook(issueType?.OnCloseActionID, issue, contextUser);
    }
    return true;
  }

  /**
   * Assigns an issue to a polymorphic assignee (Person or AI Agent), saves, and fires OnAssign.
   * Pass null/null to clear the assignee. Returns true on success.
   */
  public async Assign(
    issue: mjBizAppsIssuesIssueEntity,
    assigneeEntityID: string | null,
    assigneeRecordID: string | null,
    contextUser: UserInfo,
  ): Promise<boolean> {
    await IssueEngine.Instance.Config(false, contextUser);

    issue.AssigneeEntityID = assigneeEntityID;
    issue.AssigneeRecordID = assigneeRecordID;

    if (!(await issue.Save())) {
      LogError(`IssueService.Assign: save failed: ${issue.LatestResult?.CompleteMessage ?? 'unknown error'}`);
      return false;
    }

    const issueType = IssueEngine.Instance.IssueTypeByID(issue.IssueTypeID);
    await this.fireHook(issueType?.OnAssignActionID, issue, contextUser);
    return true;
  }

  /**
   * Closes an issue by transitioning it to the supplied terminal status (or the first terminal
   * status if none given). Fires OnStatusChange + OnClose via TransitionStatus.
   */
  public async Close(
    issue: mjBizAppsIssuesIssueEntity,
    contextUser: UserInfo,
    terminalStatusID?: string,
  ): Promise<boolean> {
    await IssueEngine.Instance.Config(false, contextUser);

    const statusID = terminalStatusID ?? IssueEngine.Instance.IssueStatuses.find((s) => s.IsTerminal)?.ID;
    if (!statusID) {
      LogError('IssueService.Close: no terminal IssueStatus is configured');
      return false;
    }
    return this.TransitionStatus(issue, statusID, contextUser);
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  /** Resolves the IssueType from explicit ID or name via the engine cache. */
  private resolveIssueType(params: CreateIssueParams): mjBizAppsIssuesIssueTypeEntity | undefined {
    if (params.IssueTypeID) {
      return IssueEngine.Instance.IssueTypeByID(params.IssueTypeID);
    }
    if (params.IssueTypeName) {
      return IssueEngine.Instance.IssueTypeByName(params.IssueTypeName);
    }
    return undefined;
  }

  /** Stamps ResolvedAt/ClosedAt when entering a terminal state; clears them when leaving. */
  private stampLifecycleTimestamps(issue: mjBizAppsIssuesIssueEntity, isTerminal: boolean): void {
    if (isTerminal) {
      const now = new Date();
      if (!issue.ResolvedAt) {
        issue.ResolvedAt = now;
      }
      issue.ClosedAt = now;
    } else {
      // Re-opened: clear the closed timestamp (keep ResolvedAt history intact).
      issue.ClosedAt = null;
    }
  }

  /**
   * Fires an IssueType action hook by Action ID, passing the issue's identity as input params.
   * No-op when actionID is null/undefined. Failures are logged, never thrown — a misconfigured
   * hook must not break the issue mutation that triggered it.
   */
  private async fireHook(
    actionID: string | null | undefined,
    issue: mjBizAppsIssuesIssueEntity,
    contextUser: UserInfo,
  ): Promise<void> {
    if (!actionID) {
      return;
    }
    try {
      await ActionEngineServer.Instance.Config(false, contextUser);
      const action = ActionEngineServer.Instance.Actions.find((a) => a.ID === actionID);
      if (!action) {
        LogError(`IssueService.fireHook: Action ${actionID} not found`);
        return;
      }

      const params: ActionParam[] = [
        { Name: 'IssueID', Value: issue.ID, Type: 'Input' },
        { Name: 'Title', Value: issue.Title, Type: 'Input' },
        { Name: 'StatusID', Value: issue.StatusID, Type: 'Input' },
        { Name: 'Priority', Value: issue.Priority, Type: 'Input' },
        { Name: 'Severity', Value: issue.Severity, Type: 'Input' },
      ];

      await ActionEngineServer.Instance.RunAction({
        Action: action,
        ContextUser: contextUser,
        Params: params,
        Filters: [],
      });
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      LogError(`IssueService.fireHook: failed to run Action ${actionID}: ${msg}`);
    }
  }
}
