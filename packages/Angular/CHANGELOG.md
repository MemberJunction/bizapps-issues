# @mj-biz-apps/issues-ng

## 1.3.0

### Minor Changes

- 00f352b: Add predictive critical escalation outcome columns, layered base views (vwIssuesGenerated and vwIssues), and scoring binding write-back.

### Patch Changes

- 96ecc04: License declarations now agree on BUSL-1.1 everywhere.

  The Open App manifest (`mj-app.json`) declared `"license": "ISC"` and the README badge
  advertised ISC, while `LICENSE` and every `package.json` declared BUSL-1.1. The manifest is
  what an MJ deployment reads on install and the badge is the first thing a reader sees, so
  between them they were the repo's loudest license statement — and the wrong one. The badge
  now links to `LICENSE`.

- Updated dependencies [96ecc04]
- Updated dependencies [00f352b]
  - @mj-biz-apps/issues-entities@1.3.0

## 1.2.0

### Patch Changes

- 925c48e: Add Application Roles metadata granting access for UI and Developer roles to the Issues application.
- cbd2206: Declare `@memberjunction/ng-shared` as a peer of issues-ng — the section resources import `BaseResourceComponent` from it, and under a strict pnpm layout the undeclared module doesn't resolve and `ngc` fails. Ship the v1.2.x metadata sync migration so a migrations-only install carries the Issues application record, its application roles, and the form-chrome placements with no `mj sync push` required.
- Updated dependencies [461220b]
- Updated dependencies [448eed4]
- Updated dependencies [d4afb26]
- Updated dependencies [cbd2206]
  - @mj-biz-apps/issues-entities@1.2.0

## 1.1.1

### Patch Changes

- Updated dependencies [5de28dd]
  - @mj-biz-apps/issues-entities@1.1.1

## 1.1.0

### Minor Changes

- 3980538: PG fix

### Patch Changes

- Updated dependencies [3980538]
  - @mj-biz-apps/issues-entities@1.1.0

## 1.0.1

### Patch Changes

- 56db7f4: Converted mj-app.json deps to object; added publish.yml version-sync steps.
- Updated dependencies [56db7f4]
  - @mj-biz-apps/issues-entities@1.0.1
