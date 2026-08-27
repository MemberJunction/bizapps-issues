# @mj-biz-apps/issues-entities

## 1.2.0

### Minor Changes

- 461220b: Person-form Issues use L1 inclusion: Reporter is Primary; created-by Issues and issue comments are None. Issue comments stay Primary on the Issue form.
- 448eed4: Issue form uses left-nav. Comments stay first-class.
- d4afb26: Punch Issues reported by a Person (ReporterPersonID) as FormRole Primary so that grid stays first-class on the Person form.
- cbd2206: Declare `@memberjunction/ng-shared` as a peer of issues-ng — the section resources import `BaseResourceComponent` from it, and under a strict pnpm layout the undeclared module doesn't resolve and `ngc` fails. Ship the v1.2.x metadata sync migration so a migrations-only install carries the Issues application record, its application roles, and the form-chrome placements with no `mj sync push` required.

## 1.1.1

### Patch Changes

- 5de28dd: Upgrade to MemberJunction 6.x, migrate the workspace to pnpm, and remove the
  MJAPI/MJExplorer dev harness.

  **Hosts must be on a MemberJunction 6.x environment.** No application source changed,
  so this is a `patch` — the repo's convention reserves `minor` for migration and
  metadata changes, and this branch carries neither. Every `@memberjunction/*`
  dependency, devDependency and peer range moves to `^6.1.0-edge.2`, the estate-wide
  floor, and `mj-app.json`'s `mjVersionRange` becomes `>=6.1.0-edge.2 <7.0.0`. The
  prerelease-tagged lower bound is required: node-semver will not match a prerelease
  against a plain `>=6.1.0`. The ranges are carets rather than exact pins because an
  exact pin does not satisfy a local sibling's version under pnpm, so workspace links
  silently fall back to the registry.

  `@mj-biz-apps/common-*` moves to `^5.34.0` and `tasks-*` to `^1.2.2`. The common floor
  is **not** cosmetic: 5.33.x imports `UserCache` from `@memberjunction/sqlserver-dataprovider`,
  which MJ 6.x moved to `@memberjunction/generic-database-provider`, so app bootstrap dies
  with `does not provide an export named 'UserCache'`. 5.34.0 is the first build that
  loads on a 6.x host.

  **pnpm migration.** `packageManager` moves to `pnpm@10.33.0`, `package-lock.json` is
  replaced by `pnpm-lock.yaml`, the npm `overrides` block moves to `pnpm.overrides`, and CI
  installs with `pnpm install --frozen-lockfile`. Two workspace settings are load-bearing and
  mirror MJ core: `linkWorkspacePackages: true` (pnpm 10 defaults it false, which resolves
  this repo's exact-pinned internal packages from the registry instead of linking them
  locally) and an `onlyBuiltDependencies` allowlist (pnpm 10 runs no dependency build scripts
  without one). `.npmrc`'s `save-exact=true` is dropped for the same reason the ranges
  became carets.

  **The dev harness is gone.** `apps/MJAPI` and `apps/MJExplorer` were private and
  unpublished; the `@mj-biz-apps/issues-*` packages are what this repo ships. They existed
  because there was no way to exercise the app against a real MJ instance, and MJ 6.x
  workspace linking now provides one. Removing them also retires a real failure: under pnpm's
  default layout an in-repo MJAPI cannot boot, because `@memberjunction/server` resolves to
  two physical copies (same version, different peer-resolution hashes) and type-graphql's
  process-global metadata storage then rejects a duplicate `RunViewByIDInput`. With the app
  gone there is no process to fail — and measurably so: a clean install now resolves all 202
  `@memberjunction/*` packages to a single version, where the harness previously produced 86
  duplicated.

  Two pre-existing defects fixed along the way:

  - `mj:migrate` was bare `mj migrate`, with no `--schema` or `--dir`, so it reported
    "0 applied" and silently did nothing — the app's own migrations could not be applied
    through it at all. It is now
    `mj migrate --schema __mj_BizAppsIssues --dir ./migrations`.
  - The publish step deriving `mj-app.json`'s upstream ranges read the removed dev harness.
    Both derivations now read `packages/Core` and the upstream `-entities` packages (each
    upstream OpenApp version-locks its packages as a fixed group, so it is the same number),
    and the guards fail loudly instead of skipping — the previous `if [ -n "$DEP" ]` shape
    would have let the manifest silently stop updating on every release.

## 1.1.0

### Minor Changes

- 3980538: PG fix

## 1.0.1

### Patch Changes

- 56db7f4: Converted mj-app.json deps to object; added publish.yml version-sync steps.
