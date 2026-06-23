import { Metadata, UserInfo, LogError } from '@memberjunction/core';

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
 * Convenience service for the common issue operations: create, transition status,
 * assign, and close.
 *
 * IMPORTANT — this service is a THIN convenience layer. The authoritative lifecycle
 * side-effects (IssueNumber assignment, ResolvedAt/ClosedAt stamping, and firing the
 * IssueType OnCreate/OnStatusChange/OnClose/OnAssign action hooks) live in
 * `IssueEntityServer.Save()` so they fire on EVERY save path — including a plain
 * `entity.Save()` from the UI/API/automation that never touches this service. These
 * methods just set the right field(s) and call Save(); the entity does the rest.
 *
 * Server-side: always pass contextUser.
 */
export class IssueService {
  /**
   * Creates a new Issue. Resolves the IssueType (by ID or name) and defaults status to
   * the IsDefault status and priority to the type's DefaultPriority, then saves. The
   * entity server assigns IssueNumber, stamps lifecycle timestamps, and fires OnCreate.
   * Returns the saved entity, or null on failure (details logged).
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
    return issue;
  }

  /**
   * Transitions an issue to a new status by setting StatusID and saving. The entity
   * server stamps ResolvedAt/ClosedAt and fires OnStatusChange (+ OnClose on terminal).
   * No-ops when the status is unchanged. Returns true on success.
   */
  public async TransitionStatus(
    issue: mjBizAppsIssuesIssueEntity,
    newStatusID: string,
    contextUser: UserInfo,
  ): Promise<boolean> {
    await IssueEngine.Instance.Config(false, contextUser);

    if (!IssueEngine.Instance.IssueStatusByID(newStatusID)) {
      LogError(`IssueService.TransitionStatus: unknown status ID ${newStatusID}`);
      return false;
    }
    if (issue.StatusID === newStatusID) {
      return true; // no-op
    }

    issue.StatusID = newStatusID;
    if (!(await issue.Save())) {
      LogError(`IssueService.TransitionStatus: save failed: ${issue.LatestResult?.CompleteMessage ?? 'unknown error'}`);
      return false;
    }
    return true;
  }

  /**
   * Assigns an issue to a polymorphic assignee (Person or AI Agent) and saves. The
   * entity server fires OnAssign. Pass null/null to clear the assignee. Returns true
   * on success.
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
    return true;
  }

  /**
   * Closes an issue by transitioning it to the supplied terminal status (or the first
   * terminal status if none given). The entity server stamps ClosedAt and fires
   * OnStatusChange + OnClose.
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
}
