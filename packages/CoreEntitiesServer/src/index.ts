/**
 * @mj-biz-apps/issues-core-entities-server
 *
 * Server-side entity subclasses for BizApps Issues entities. These classes
 * override Save()/Delete() to add lifecycle hooks that only run on the server
 * (stamp ResolvedAt/ClosedAt on status transitions, fire IssueType action hooks,
 * etc.).
 *
 * Import this package from the server bootstrap so @RegisterClass decorators
 * fire at startup. Subclasses are added in Phase 4.
 */

export {}
