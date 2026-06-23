import { Metadata, UserInfo, LogError } from '@memberjunction/core';

import {
  mjBizAppsTasksTaskEntity,
  mjBizAppsTasksTaskLinkEntity,
} from '@mj-biz-apps/tasks-entities';
import { mjBizAppsIssuesIssueEntity } from '@mj-biz-apps/issues-entities';

import { IssueEngine } from './IssueEngine.js';

/** Task priority enum (mirrors bizapps-tasks Task.Priority). */
export type TaskPriority = 'Low' | 'Medium' | 'High' | 'Critical';

/** Parameters for spawning work from an issue. */
export interface SpawnTaskParams {
  /** Task name; defaults to the issue Title. */
  Name?: string;
  Description?: string | null;
  /**
   * The bizapps-tasks TaskType for the spawned Task. If omitted, falls back to the issue's
   * IssueType.DefaultTaskTypeID. Required — a Task cannot be created without a TypeID.
   */
  TaskTypeID?: string;
  /** Task priority; defaults to the issue's Priority. */
  Priority?: TaskPriority;
}

/**
 * Bridges an Issue to the bizapps-tasks work-management system. An Issue does not own a
 * work-item table; instead it spawns a Task (bizapps-tasks) and links it back to the Issue via
 * the existing polymorphic TaskLink (EntityID = the Issues entity, RecordID = the Issue's ID).
 * Sub-tasks, assignment, dependencies, and Kanban/Gantt all come from bizapps-tasks for free.
 *
 * Server-side: always pass contextUser.
 */
export class IssueWorkService {
  /**
   * Creates a Task for the given issue and a TaskLink pointing back at the issue. Returns the
   * saved Task, or null on failure (details logged). Resolves the TaskType from the param or the
   * issue's IssueType.DefaultTaskTypeID; fails clearly if neither is available.
   */
  public async SpawnTask(
    issue: mjBizAppsIssuesIssueEntity,
    contextUser: UserInfo,
    params: SpawnTaskParams = {},
  ): Promise<mjBizAppsTasksTaskEntity | null> {
    await IssueEngine.Instance.Config(false, contextUser);

    const taskTypeID = this.resolveTaskTypeID(issue, params);
    if (!taskTypeID) {
      LogError(`IssueWorkService.SpawnTask: no TaskTypeID provided and IssueType for issue ${issue.ID} has no DefaultTaskTypeID`);
      return null;
    }

    const issuesEntityID = this.getIssuesEntityID();
    if (!issuesEntityID) {
      LogError('IssueWorkService.SpawnTask: could not resolve the "MJ_BizApps_Issues: Issues" entity ID');
      return null;
    }

    const md = new Metadata();

    const task = await md.GetEntityObject<mjBizAppsTasksTaskEntity>('MJ_BizApps_Tasks: Tasks', contextUser);
    task.NewRecord();
    task.Name = params.Name ?? issue.Title;
    task.Description = params.Description ?? issue.Description ?? null;
    task.TypeID = taskTypeID;
    task.Status = 'Open';
    task.Priority = params.Priority ?? (issue.Priority as TaskPriority);

    if (!(await task.Save())) {
      LogError(`IssueWorkService.SpawnTask: task save failed: ${task.LatestResult?.CompleteMessage ?? 'unknown error'}`);
      return null;
    }

    const link = await md.GetEntityObject<mjBizAppsTasksTaskLinkEntity>('MJ_BizApps_Tasks: Task Links', contextUser);
    link.NewRecord();
    link.TaskID = task.ID;
    link.EntityID = issuesEntityID;
    link.RecordID = issue.ID;
    link.Description = `Spawned from issue: ${issue.Title}`;

    if (!(await link.Save())) {
      LogError(`IssueWorkService.SpawnTask: task link save failed: ${link.LatestResult?.CompleteMessage ?? 'unknown error'}`);
      // The Task was created but the link failed — surface the partial state to the caller.
      return null;
    }

    return task;
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  /** Resolves the TaskType: explicit param wins, else the issue's IssueType.DefaultTaskTypeID. */
  private resolveTaskTypeID(issue: mjBizAppsIssuesIssueEntity, params: SpawnTaskParams): string | null {
    if (params.TaskTypeID) {
      return params.TaskTypeID;
    }
    return IssueEngine.Instance.IssueTypeByID(issue.IssueTypeID)?.DefaultTaskTypeID ?? null;
  }

  /** Resolves the __mj.Entity ID for the Issues entity (the polymorphic TaskLink target). */
  private getIssuesEntityID(): string | undefined {
    return new Metadata().EntityByName('MJ_BizApps_Issues: Issues')?.ID;
  }
}
