/**
 * @mj-biz-apps/issues-core
 *
 * Core logic for the BizApps Issues Open App:
 *  - IssueEngine        — cached/reactive lookup of IssueTypes & IssueStatuses
 *  - IssueService       — create / triage / transition / close, fires IssueType action hooks
 *  - IssueWorkService   — spawns linked bizapps-tasks Tasks via TaskLink
 *
 * Server-side entity subclasses (lifecycle hooks) live in the separate
 * @mj-biz-apps/issues-core-entities-server package.
 */

export * from './services/IssueEngine.js';
export * from './services/IssueService.js';
export * from './services/IssueWorkService.js';
