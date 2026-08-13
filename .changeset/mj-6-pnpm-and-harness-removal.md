---
"@mj-biz-apps/issues-entities": patch
---

Upgrade to MemberJunction 6.1.0-edge.1, migrate the workspace to pnpm, and remove the
MJAPI/MJExplorer dev harness.

**Hosts must be on a MemberJunction 6.x environment** — that is why this is minor rather
than patch, even though no application source changed. Every `@memberjunction/*`
dependency, devDependency and peer range moves to the exact `6.1.0-edge.1` prerelease, and
`mj-app.json`'s `mjVersionRange` becomes `>=6.1.0-edge.1 <7.0.0`. The prerelease-tagged
lower bound is required: node-semver will not match a prerelease against a plain `>=6.1.0`.
`@mj-biz-apps/common-*` moves to 5.33.1 and `tasks-*` to 1.2.1 — the first builds of each
that peer on the MJ 6.x line.

**pnpm migration.** `packageManager` moves to `pnpm@10.33.0`, `package-lock.json` is
replaced by `pnpm-lock.yaml`, the npm `overrides` block moves to `pnpm.overrides`, and CI
installs with `pnpm install --frozen-lockfile`. Two workspace settings are load-bearing and
mirror MJ core: `linkWorkspacePackages: true` (pnpm 10 defaults it false, which resolves
this repo's exact-pinned internal packages from the registry instead of linking them
locally) and an `onlyBuiltDependencies` allowlist (pnpm 10 runs no dependency build scripts
without one).

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
