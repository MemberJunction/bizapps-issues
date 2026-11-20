/**
 * @mj-biz-apps/issues-core-entities-server
 *
 * Server-side entity subclasses for BizApps Issues entities. These hold side-effects
 * that must run server-only and authoritatively (not in the browser) — currently the
 * assignment of the human-readable Issue.IssueNumber via DocumentNumberingEngine +
 * atomic DB sequence routine.
 *
 * Import this package (or call LoadBizAppsIssuesEntitiesServer) from the server
 * bootstrap so the @RegisterClass decorators and numbering policies fire at startup.
 */

import { IssueEntityServer } from './IssueEntityServer.js';
import { IssueCommentEntityServer } from './IssueCommentEntityServer.js';
import { registerIssueNumberingPolicy } from './SequenceService.js';

export { IssueEntityServer } from './IssueEntityServer.js';
export { IssueCommentEntityServer } from './IssueCommentEntityServer.js';
export {
  CustomRoutineDocumentSequenceStore,
  ISSUES_ENTITY_NAME,
  ISSUE_NUMBERING_POLICY,
  SequenceService,
  registerIssueNumberingPolicy,
  type SequenceSQL,
} from './SequenceService.js';

/**
 * Forces the server-side entity subclasses to load so their @RegisterClass
 * decorators register (priority 2, overriding the client-shared entities) and
 * ensures the Issues `DocumentNumberingEngine` policy is registered.
 */
export function LoadBizAppsIssuesEntitiesServer(): void {
  // Reference the classes so the imports are retained and their decorators run.
  void IssueEntityServer;
  void IssueCommentEntityServer;
  registerIssueNumberingPolicy();
}
