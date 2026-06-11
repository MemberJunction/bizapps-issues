/**
 * @mj-biz-apps/issues-core-entities-server
 *
 * Server-side entity subclasses for BizApps Issues entities. These hold side-effects
 * that must run server-only and authoritatively (not in the browser) — currently the
 * assignment of the human-readable Issue.IssueNumber via an atomic DB sequence proc.
 *
 * Import this package (or call LoadBizAppsIssuesEntitiesServer) from the server
 * bootstrap so the @RegisterClass decorators fire at startup.
 */

import { IssueEntityServer } from './IssueEntityServer.js';

export { IssueEntityServer } from './IssueEntityServer.js';
export { SequenceService } from './SequenceService.js';

/**
 * Forces the server-side entity subclasses to load so their @RegisterClass
 * decorators register (priority 2, overriding the client-shared entities).
 * Tree-shaking would otherwise drop them since they're referenced only via the
 * class factory.
 */
export function LoadBizAppsIssuesEntitiesServer(): void {
  // Reference the class so the import is retained and its decorator runs.
  void IssueEntityServer;
}
