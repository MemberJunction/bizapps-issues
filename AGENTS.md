# AGENTS.md — BizApps Issues (`MemberJunction/bizapps-issues`)

Authoritative repo guide: see [`CLAUDE.md`](CLAUDE.md).

## Package Tiers (`mj-app.json`)

| Package | Tier | Purpose |
| --- | --- | --- |
| `@mj-biz-apps/issues-entities` | `shared` | Generated entity subclasses (`src/generated/`, never hand-edit) + shared `IssueEngineBase` (`src/engine/IssueEngineBase.ts`) |
| `@mj-biz-apps/issues-ng` | `client` | Angular dashboards, triage views, detail drawer, and Report Issue dialog (depends on `issues-entities`, never server packages) |
| `@mj-biz-apps/issues-core` | `server` | Server services (`IssueEngine`, `IssueService`, `IssueWorkService`) + Vitest unit test suite |
| `@mj-biz-apps/issues-core-entities-server` | `server` | Server-side entity overrides (`IssueEntityServer`, `IssueCommentEntityServer`) |
| `@mj-biz-apps/issues-actions` | `server` | MJ Actions for issue lifecycle operations |
| `@mj-biz-apps/issues-server` | `server` | Server bootstrap (`LoadBizAppsIssuesServer`) |

## Non-Negotiable Coding Rules

- **ZERO `any` or lazy `unknown`** (no `Record<string, unknown>` for entity rows — define typed projections deriving union types from generated entities, e.g. `mjBizAppsIssuesIssueEntity['Severity']`).
- **ZERO `.Get()` / `.Set()`** on generated entities — always use typed properties.
- **`BaseSingleton` / `BaseEngine`** for all singletons — never manual `static _instance`.
- **Modern Angular syntax** (`@if`/`@for`/`@switch`, `inject()`) and **ZERO cross-package re-exports**.
- **Never edit `src/generated/` or `ci/` protected files**; stage explicitly (`git add <file>`), target PRs to `next`, and merge with standard merge commits (`--merge`, never `--squash`).

## 5-Rule BizApps Performance & Caching Standard

1. **`BaseEngine` for bounded taxonomy/config metadata:**
   - Use `IssueEngineBase.Instance` (`@mj-biz-apps/issues-entities`) in Angular/shared code and `IssueEngine.Instance` (`@mj-biz-apps/issues-core`) in server services for `MJ_BizApps_Issues: Issue Types` and `MJ_BizApps_Issues: Issue Status`.
   - Call `await IssueEngineBase.Instance.Config(false, contextUser, provider)` lazily; never bulk-cache unbounded transactional entities (`Issues`, `Issue Comments`).
2. **Multi-provider, impersonation, and RLS `CacheLocal` safety:**
   - Override `ProviderToUse` to honor active explicit providers, pass `provider` unchanged to `super.Load(...)` (never `provider ?? Metadata.Provider`), force refresh on provider switch, gate configs with `CanRead`, and keep `CacheLocal: false` on any RLS-protected or user-scoped entity (`CacheLocal: true` only for global non-RLS lookup tables).
   - Server entity overrides must pass `this.RunViewProviderToUse` to `new RunView(this.RunViewProviderToUse)`.
3. **Batch `RunView` waterfalls via `rv.RunViews([...])` + `ResultType: 'simple'` + `Fields`:**
   - Eliminate sequential independent `await rv.RunView(...)` calls and `Promise.all([new RunView().RunView(...), ...])` by batching into a single `rv.RunViews([...])` call (`RunView.FromMetadataProvider(this.ProviderToUse)` where available).
   - Always pass `ResultType: 'simple'` and explicit `Fields: [...]` on read-only queries.
4. **Bounded per-container caching (`ConversationEngine` pattern) — never cache arbitrary filtered lists:**
   - Scope any per-container detail cache to `(containerId, viewerUserId)` with bounded capacity and automatic `BaseEntity` save/delete + user/provider switch invalidation. Never cache arbitrary filtered list queries globally.
5. **RLS-safe two-step entity reads:**
   - Resolve scoping IDs via a first-class `RunView` on the junction/scoping entity, fast-path empty results, and query target records using chunked `ID IN (...)` predicates — never raw SQL subqueries that bypass RLS.

## Verification

```sh
pnpm run build:packages
pnpm run test
```
