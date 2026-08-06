---
"@mj-biz-apps/issues-core": patch
"@mj-biz-apps/issues-core-entities-server": patch
---

Declare the dependencies these packages actually use.

`issues-core` imports `rxjs` in `IssueEngine.ts` but never declared it; it resolved by hoisting when
this repo was its own npm root. Under a shared pnpm workspace it does not, and the package fails to
compile with `TS2307: Cannot find module 'rxjs'`. Declared at the `^7.8.2` its siblings use.

`vitest` was likewise declared only at the repo root, so under the workspace every suite here failed
to launch with `vitest: command not found`. Declared in the two packages that have test files.
