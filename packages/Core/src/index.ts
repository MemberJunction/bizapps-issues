/**
 * @mj-biz-apps/issues-core
 *
 * Core logic for the BizApps Issues Open App:
 *  - IssueEngine        — cached/reactive lookup of IssueTypes & IssueStatuses (Phase 4)
 *  - IssueService       — create / triage / transition / close, fires IssueType action hooks (Phase 4)
 *  - IssueWorkService   — spawns linked bizapps-tasks Tasks via TaskLink (Phase 4)
 *
 * Server-side entity subclasses (lifecycle hooks) live in the separate
 * @mj-biz-apps/issues-core-entities-server package.
 *
 * Exports below are populated in Phase 4. The barrel intentionally starts empty
 * so the package builds against freshly-generated entities before services exist.
 */

export {}
