---
"@mj-biz-apps/issues-core-entities-server": patch
---

Declare `@mj-biz-apps/issues-core-entities-server` under `packages.server` in `mj-app.json` instead of
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
