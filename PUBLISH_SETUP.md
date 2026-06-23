# Publishing Setup — bizapps-issues

This repo publishes the six `@mj-biz-apps/issues-*` packages to npm using a
Changesets-based pipeline, modeled on **bizapps-tasks** / **bizapps-common**
(`MemberJunction/bizapps-tasks`). The workflow files, validator scripts, `ci/`
helpers, and Changesets config are already in place.

## Branch model

```
feature branch ──PR──▶ next ──(merge)──▶ main ──(push triggers publish.yml)──▶ npm
```

- PRs land on **`next`**. `build.yml` + `changes.yml` run as checks.
- Changesets (`.changeset/*.md`) accumulate on `next`. A migration-bearing PR to
  `next` is *required* to include a changeset with at least a `minor` bump
  (`changes.yml` enforces this).
- Releasing = merging **`next` → `main`**. The push to `main` fires `publish.yml`,
  which (if pending changesets exist) bumps the fixed version across all six
  packages, builds, `changeset publish` to npm, tags `vX.Y.Z`, commits the bump
  back to `main`, then merges `main` → `next` and refreshes the lockfile.
- If there are **no** pending changesets, a push to `main` is a no-op.

> **Setup required:** the remote currently has only `main`. Before this flow
> works you must create a **`next`** branch (`git push origin main:next`) and
> make it the repository's default branch on GitHub, so PRs target `next`.
> The Changesets `baseBranch` stays `main` (matching bizapps-tasks) — it is the
> comparison base for `changeset version`, not the PR target.

> **Branch protection:** like bizapps-tasks, `main` is **not** protected. The
> "publish only flows next→main" rule is a *convention*, enforced by discipline,
> not by a ruleset. `publish.yml` pushes the version-bump commit back to `main`
> using the default `GITHUB_TOKEN`, which works because `main` is open.

## npm authentication — OIDC (no NPM_TOKEN secret)

This repo publishes via **npm OIDC trusted publishing**, the same as
bizapps-tasks. The workflow declares `id-token: write` and npm verifies the
GitHub Actions OIDC identity at publish time — there is **no `NPM_TOKEN` secret**
to manage.

One-time setup on npmjs.com (per package, by an `@mj-biz-apps` org owner): under
each package's **Settings → Trusted Publisher**, add this repo
(`MemberJunction/bizapps-issues`) and the `publish.yml` workflow. Trusted
publishing can only be configured *after* the package exists, so it happens
together with the placeholder publish below.

## First publish — npm placeholders

The six packages do **not** yet exist on npm (all return 404), and
`validate-npm-packages.sh` fails the publish job until every package has at least
a placeholder version published. Publish a `0.0.0` placeholder for each **once,
manually**, then the automated flow takes over:

- `@mj-biz-apps/issues-entities`
- `@mj-biz-apps/issues-core`
- `@mj-biz-apps/issues-core-entities-server`
- `@mj-biz-apps/issues-actions`
- `@mj-biz-apps/issues-server`
- `@mj-biz-apps/issues-ng`

After publishing each placeholder, configure its **Trusted Publisher** on npm
(see above) so the automated OIDC publish works.

## Checklist

- [ ] Create `next` branch on the remote (`git push origin main:next`) and set it as the default branch
- [ ] Publish `0.0.0` placeholders for all six packages (manually, with a token)
- [ ] Configure npm Trusted Publisher for each package → `MemberJunction/bizapps-issues` / `publish.yml`
- [ ] Land a changeset on `next`, merge `next` → `main`, confirm `publish.yml` publishes + tags

## Notes / divergences from bizapps-tasks

- **Migration validators are ACTIVE here** (unlike bizapps-tasks, where they pass
  vacuously). bizapps-issues ships real `V[0-9]{12}`-prefixed migrations, so
  `validate-migration-filenames.sh` and the timestamp/changeset gates in
  `changes.yml` genuinely enforce naming, monotonic timestamps, and the
  changeset requirement on migration-bearing PRs to `next`. The `B`-prefixed
  baseline (`B202606091000__…`) is not matched by the `V`-only gates — that's
  intentional; baselines are exempt.
- **Six packages, not five.** bizapps-issues adds `@mj-biz-apps/issues-core-entities-server`
  (server-side entity subclasses) on top of the entities/core/actions/server/ng set.
- The version-detection package (`packages/Entities/package.json`) and the fixed
  `@mj-biz-apps/*` version group mean all six publish in lockstep at one version.
- **PostgreSQL note:** the `migrations-pg/` set is maintained separately (see
  `docs/postgresql.md`). The CI migration validators target `migrations/` (the
  canonical SQL Server set); `migrations-pg/` files use a `.pg.sql`/`.pg-only.sql`
  suffix and are not matched by the `V[0-9]{12}…\.sql$` gates.
