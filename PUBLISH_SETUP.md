# Publishing Setup — bizapps-issues

This repo publishes the six `@mj-biz-apps/issues-*` packages to npm using a
Changesets-based pipeline, modeled on **bizapps-tasks** / **bizapps-common**
(`MemberJunction/bizapps-tasks`). The workflow files, validator scripts, `ci/`
helpers, and Changesets config are already in place.

## Branch model

```
feature PR ──▶ next ──(version.yml)──▶ Version Packages PR (changeset-release/main ──▶ main)
                                              │ reviewed + merged = the release
                                              ▼
                               main ──(publish.yml)──▶ npm + tag vX.Y.Z
                                              │
                                              ▼
                               back-merge PR main ──▶ next (opened + merged by the App)
```

- Feature PRs land on **`next`** with a changeset. `build.yml` and `changes.yml` run as checks.
  A migration-bearing PR must carry at least a `minor` changeset.
- Every push to `next` refreshes one **Version Packages** PR (`version.yml`, using
  `changesets/action@v1` with `branch: main`). It runs `changeset version`, so its diff shows the
  exact version bump, changelog entries and `mj-app.json` version. **That PR is the release.**
- PRs into `main` run the `rr:` gates (`release-readiness.yml`) plus `build`.
- Merging the Version Packages PR pushes to `main`, which fires `publish.yml`: build,
  `changeset publish`, and a `vX.Y.Z` tag **only if something actually shipped**.
- `publish.yml` then opens and merges a `main → next` back-merge PR with the GitHub App token,
  so `next` always contains the released versions. `rr: release base current` fails the next
  release if that back-merge never landed.
- A push to `main` with nothing new to publish ships nothing and creates no tag.

> **Branch protection** (applied). `next` (`protect-next`): changes arrive by pull request with
> the door checks required and the branch up to date, and **no approval required**. The App is a
> `pull_request`-mode bypass actor, so the back-merge can merge the moment it opens. `main`
> (`protect-main`): the `rr:` checks and `build` required, **one approval** with
> dismiss-stale-reviews, no bypass.

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

## First publish — npm placeholders (done for the current six)

All six packages exist on npm (1.3.0 as of 2026-09-30), so this is only needed when a **new**
package is added. `validate-npm-packages.sh` fails the publish job while any publishable
`@mj-biz-apps/*` package is missing from npm, because CI cannot create a package over OIDC.

For each new package, once, by an `@mj-biz-apps` org owner:

1. `npx setup-npm-trusted-publish <package-name>` — publishes a placeholder so the package exists.
2. Configure its **Trusted Publisher** at `https://www.npmjs.com/package/<package-name>/access`
   → `MemberJunction/bizapps-issues`, workflow `publish.yml`.
3. Re-run the publish. CI handles every later version.

Packages marked `"private": true` (e.g. `issues-integration-tests`) are skipped — changesets never
publishes them.

## Checklist for a release

- [ ] Changesets merged to `next`; the Version Packages PR shows the expected version
- [ ] All `rr:` gates and `build` green on that PR
- [ ] Merge it; confirm `publish.yml` published and tagged
- [ ] Confirm the `release-back-merge/vX.Y.Z` PR merged into `next`

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
