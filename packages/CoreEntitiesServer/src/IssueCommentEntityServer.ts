import { BaseEntity, EntitySaveOptions, LogError, RunView, UserInfo } from '@memberjunction/core';
import { RegisterClass, UUIDsEqual } from '@memberjunction/global';
import { mjBizAppsIssuesIssueCommentEntity } from '@mj-biz-apps/issues-entities';

/** People entity (bizapps-common) — resolved at runtime by name; the comment's AuthorPersonID FKs into it. */
const PEOPLE_ENTITY = 'MJ_BizApps_Common: People';

/** Comment fields whose modification is treated as a content edit (author-only). */
const CONTENT_FIELDS = ['Body', 'Source', 'IssueID'] as const;

/**
 * Server-side subclass of {@link mjBizAppsIssuesIssueCommentEntity}.
 *
 * Owns the SERVER-ONLY authorship guarantees that must hold on EVERY save path
 * (UI, API, automation) — the client-shared entity accepts whatever the caller
 * sets, so without this class any user could create comments as someone else or
 * edit other people's comments:
 *
 *   1. **Author stamping (insert)** — AuthorPersonID / AuthorEmail are derived
 *      from `this.ContextCurrentUser`, overriding any client-supplied values.
 *      The Person is resolved from the MJ user via `People.LinkedUserID` (with
 *      an Email fallback, since LinkedUserID is deprecated in bizapps-common);
 *      when no Person is linked, AuthorPersonID is null and AuthorEmail carries
 *      the authenticated user's email.
 *   2. **Author immutability + author-only edits (update)** — AuthorPersonID /
 *      AuthorEmail can never change after insert, and content edits (Body,
 *      Source, IssueID) are rejected unless the context user IS the author.
 *
 * Registered at priority 2 so this server subclass wins over the priority-1
 * client-shared entity (same as IssueEntityServer).
 */
@RegisterClass(BaseEntity, 'MJ_BizApps_Issues: Issue Comments', 2)
export class IssueCommentEntityServer extends mjBizAppsIssuesIssueCommentEntity {
  public override async Save(options?: EntitySaveOptions): Promise<boolean> {
    if (!this.IsSaved) {
      await this.stampAuthorFromContextUser();
    } else {
      await this.enforceAuthorOnlyEdits();
    }
    return super.Save(options);
  }

  // ------------------------------------------------------------------
  // 1. Author stamping (insert)
  // ------------------------------------------------------------------

  /**
   * Stamps AuthorPersonID/AuthorEmail from the authenticated context user,
   * discarding whatever the client sent. Comment authorship is a server fact.
   */
  private async stampAuthorFromContextUser(): Promise<void> {
    const user = this.ContextCurrentUser;
    if (!user) {
      const msg = 'IssueCommentEntityServer: cannot create a comment without a context user';
      LogError(msg);
      throw new Error(msg);
    }
    this.AuthorPersonID = await this.resolveContextPersonID(user);
    this.AuthorEmail = user.Email ?? null;
  }

  // ------------------------------------------------------------------
  // 2. Author immutability + author-only content edits (update)
  // ------------------------------------------------------------------

  /**
   * On update: rejects any change to the authorship fields, and rejects content
   * edits (Body/Source/IssueID) unless the context user is the original author.
   */
  private async enforceAuthorOnlyEdits(): Promise<void> {
    const authorshipDirty =
      (this.GetFieldByName('AuthorPersonID')?.Dirty ?? false) ||
      (this.GetFieldByName('AuthorEmail')?.Dirty ?? false);
    if (authorshipDirty) {
      const msg = `IssueCommentEntityServer: comment authorship (AuthorPersonID/AuthorEmail) is immutable after insert (comment ${this.ID})`;
      LogError(msg);
      throw new Error(msg);
    }

    const contentDirty = CONTENT_FIELDS.some((f) => this.GetFieldByName(f)?.Dirty ?? false);
    if (!contentDirty) {
      return; // nothing guarded is changing
    }

    const user = this.ContextCurrentUser;
    if (!user || !(await this.contextUserIsAuthor(user))) {
      const msg = `IssueCommentEntityServer: only the comment's author may edit its content (comment ${this.ID})`;
      LogError(msg);
      throw new Error(msg);
    }
  }

  /** True when the context user maps to the comment's author (Person match, or email match for personless authors). */
  private async contextUserIsAuthor(user: UserInfo): Promise<boolean> {
    if (this.AuthorPersonID) {
      const personID = await this.resolveContextPersonID(user);
      return personID != null && UUIDsEqual(personID, this.AuthorPersonID);
    }
    // Personless (email-only) author: match on the authenticated user's email.
    return (
      this.AuthorEmail != null &&
      user.Email != null &&
      this.AuthorEmail.trim().toLowerCase() === user.Email.trim().toLowerCase()
    );
  }

  // ------------------------------------------------------------------
  // User → Person resolution
  // ------------------------------------------------------------------

  /**
   * Resolves the bizapps-common Person for an MJ user: prefers a
   * `LinkedUserID` match, falls back to an Email match (LinkedUserID is
   * deprecated in bizapps-common and may be unpopulated). Returns null when the
   * user has no Person record; failures are logged and treated as "no Person"
   * (AuthorEmail — stamped from the authenticated user — still identifies the author).
   */
  private async resolveContextPersonID(user: UserInfo): Promise<string | null> {
    const escapedUserID = user.ID.replace(/'/g, "''");
    const escapedEmail = (user.Email ?? '').replace(/'/g, "''");
    const rv = new RunView();
    const result = await rv.RunView<{ ID: string; LinkedUserID: string | null; Email: string | null }>(
      {
        EntityName: PEOPLE_ENTITY,
        ExtraFilter: escapedEmail
          ? `LinkedUserID='${escapedUserID}' OR Email='${escapedEmail}'`
          : `LinkedUserID='${escapedUserID}'`,
        Fields: ['ID', 'LinkedUserID', 'Email'],
        ResultType: 'simple',
      },
      user,
    );
    if (!result.Success) {
      LogError(`IssueCommentEntityServer: Person lookup failed for user ${user.ID}: ${result.ErrorMessage}`);
      return null;
    }
    const rows = result.Results ?? [];
    const byLink = rows.find((r) => r.LinkedUserID != null && UUIDsEqual(r.LinkedUserID, user.ID));
    if (byLink) {
      return byLink.ID;
    }
    const byEmail = rows.find(
      (r) => r.Email != null && r.Email.trim().toLowerCase() === (user.Email ?? '').trim().toLowerCase(),
    );
    return byEmail?.ID ?? null;
  }
}
