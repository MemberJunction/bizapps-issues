# Publishing Setup — bizapps-issues

This repo publishes the six `@mj-biz-apps/issues-*` packages to npm using a
Changesets-based pipeline, modeled on **bizapps-tasks** / **bizapps-common**
(`MemberJunction/bizapps-tasks`). The workflow files, validator scripts, `ci/`
helpers, and Changesets config are already in place.

## Branch model

This repo follows release lines (`guides/RELEASE_LINES.md`):

```
feature PR ──▶ next ──backport label──▶ lts/6.1 ──(version.yml)──▶ Version Packages PR (changeset-release/main ──▶ main)
                                                                          │ reviewed + merged = the release
                                                                          ▼
                                                                   main ──(publish.yml)──▶ npm + tag vX.Y.Z
                                                                          │
                                                                          ▼
                                                                   back-merge PR main ──▶ lts/6.1 + cleanup PR on next
```

- `next` is built on MJ Edge and **never versions or publishes**. Feature PRs land on **`next`**
  with a changeset. `build.yml`, `changes.yml` and `release-lines-gates.yml` run as checks.
  A migration-bearing PR must carry at least a `minor` changeset and either `backport lts/X.Y`
  labels for every open line or its files listed in `next.edgeOnlyMigrations`.
- A `backport lts/X.Y` label on a PR into `next` makes `backport.yml` open the cherry-pick PR
  into that line once it merges. The changeset travels with it.
- Every push to a line refreshes one **Version Packages** PR (`version.yml`, using
  `changesets/action@v2` with `pr-base-branch` resolved from `release-lines.json` on `next`).
  - The newest line (`releasesThrough: main`): `changeset-release/main` → `main` (dist-tag `latest`),
    with a `release-back-merge/vX.Y.Z` PR back into the line after publish.
  - An older line (`releasesThrough: branch`): `changeset-release/lts/X.Y` → `lts/X.Y` (dist-tag
    `lts-X.Y`, no back-merge needed).
- PRs into `main` (and Version Packages PRs into `lts/*`) run the `rr:` gates
  (`release-readiness.yml`), `lines: mj pin`, and `build`.
- Merging the Version Packages PR (`Cut the Release` dispatch) triggers `publish.yml`: build,
  `changeset publish --tag <dist-tag>`, verify the dist-tag, tag `vX.Y.Z` **only if something
  actually shipped**, carry the back-merge to the line (when releasing through `main`), and
  open a PR removing the consumed changesets from `next`.
- A push with nothing new to publish ships nothing and creates no tag.

> **Branch protection** (applied). `next` (`protect-next`): changes arrive by pull request with
> the door checks required and the branch up to date. The App is a `pull_request`-mode bypass
> actor. `main` (`protect-main`): the `rr:` checks and `build` required, **one approval** with
> dismiss-stale-reviews. `lts/*` (`protect-lts`): PR required, **one approval**, code-owner
> review, the `lines:` checks, the door checks and `build`, with App `pull_request`-mode bypass
> for the back-merge and an older line's release PR.

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
