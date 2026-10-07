# @mj-biz-apps/issues-core-entities-server

## 1.3.2

### Patch Changes

- 8a18b56: Declare `@mj-biz-apps/issues-core-entities-server` under `packages.server` in `mj-app.json` instead of
  `packages.shared`.

  The Open App engine imports every `shared` package into the Explorer client bundle. This package's
  entity subclasses import `@memberjunction/actions` (whose `EntityActionDispatchGuard` imports
  `node:async_hooks`) and `@memberjunction/generic-database-provider`, so the browser build failed on
  Node built-ins after installing the app. The package is only used by `@mj-biz-apps/issues-server`, which
  still imports and registers it, so server registration is unchanged.

  Upgrading an existing install removes the package's `dynamicPackages.client` entry, which is what put it
  in the browser bundle. It does not remove the npm dependency from the client workspace
  (`MJExplorer/package.json`): upgrade only adds dependencies, and only `mj app remove` removes them. The
  dependency is no longer imported; remove it by hand if the client workspace must install without the
  server-side MJ packages.

  - @mj-biz-apps/issues-core@1.3.2
  - @mj-biz-apps/issues-entities@1.3.2

## 1.3.1

### Patch Changes

- Updated dependencies [4594fae]
  - @mj-biz-apps/issues-core@1.3.1
  - @mj-biz-apps/issues-entities@1.3.1

## 1.3.0

### Patch Changes

- 96ecc04: License declarations now agree on BUSL-1.1 everywhere.

  The Open App manifest (`mj-app.json`) declared `"license": "ISC"` and the README badge
  advertised ISC, while `LICENSE` and every `package.json` declared BUSL-1.1. The manifest is
  what an MJ deployment reads on install and the badge is the first thing a reader sees, so
  between them they were the repo's loudest license statement — and the wrong one. The badge
  now links to `LICENSE`.

- Updated dependencies [96ecc04]
- Updated dependencies [00f352b]
  - @mj-biz-apps/issues-core@1.3.0
  - @mj-biz-apps/issues-entities@1.3.0

## 1.2.0

### Patch Changes

- Updated dependencies [461220b]
- Updated dependencies [448eed4]
- Updated dependencies [d4afb26]
- Updated dependencies [cbd2206]
  - @mj-biz-apps/issues-entities@1.2.0
  - @mj-biz-apps/issues-core@1.2.0

## 1.1.1

### Patch Changes

- Updated dependencies [5de28dd]
  - @mj-biz-apps/issues-entities@1.1.1
  - @mj-biz-apps/issues-core@1.1.1

## 1.1.0

### Minor Changes

- 3980538: PG fix

### Patch Changes

- Updated dependencies [3980538]
  - @mj-biz-apps/issues-entities@1.1.0
  - @mj-biz-apps/issues-core@1.1.0

## 1.0.1

### Patch Changes

- 56db7f4: Converted mj-app.json deps to object; added publish.yml version-sync steps.
- Updated dependencies [56db7f4]
  - @mj-biz-apps/issues-core@1.0.1
  - @mj-biz-apps/issues-entities@1.0.1
