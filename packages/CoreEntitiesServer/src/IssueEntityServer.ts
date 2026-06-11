import { BaseEntity, EntitySaveOptions, LogError } from '@memberjunction/core';
import { RegisterClass } from '@memberjunction/global';
import { mjBizAppsIssuesIssueEntity } from '@mj-biz-apps/issues-entities';

import { SequenceService } from './SequenceService.js';

/**
 * Server-side subclass of {@link mjBizAppsIssuesIssueEntity}.
 *
 * Holds the SERVER-ONLY side-effect of assigning the human-readable IssueNumber.
 * On insert (and only when IssueNumber is not already set), it allocates the next
 * number for the issue's AppScope via the atomic spAssignNextIssueNumber proc
 * (called through SequenceService) BEFORE super.Save() commits the row.
 *
 * IssueNumber is **immutable**: it is assigned exactly once on first insert and is
 * never re-derived, even if AppScope is later edited. Registered at priority 2 so
 * this server subclass wins over the priority-1 client-shared entity.
 *
 * Pattern mirrors bizapps-tasks' TaskEntityServer.
 */
@RegisterClass(BaseEntity, 'MJ_BizApps_Issues: Issues', 2)
export class IssueEntityServer extends mjBizAppsIssuesIssueEntity {
  public override async Save(options?: EntitySaveOptions): Promise<boolean> {
    if (!this.IsSaved && !this.IssueNumber) {
      await this.assignIssueNumber();
    }
    return super.Save(options);
  }

  /**
   * Allocates and sets the IssueNumber for a new Issue based on its AppScope.
   * Throws if allocation fails — a new issue must not be saved without a number,
   * since the value is meant to be a stable, unique reference.
   */
  private async assignIssueNumber(): Promise<void> {
    try {
      this.IssueNumber = await SequenceService.assignNextIssueNumber(this.AppScope, this);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      LogError(`IssueEntityServer: failed to assign IssueNumber (AppScope=${this.AppScope ?? '(null)'}): ${msg}`);
      throw err;
    }
  }
}
