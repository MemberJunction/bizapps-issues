---
"@mj-biz-apps/issues-actions": patch
"@mj-biz-apps/issues-core": patch
"@mj-biz-apps/issues-core-entities-server": patch
"@mj-biz-apps/issues-entities": patch
"@mj-biz-apps/issues-ng": patch
"@mj-biz-apps/issues-server": patch
---

MemberJunction and other BizApps packages are peer dependencies with caret ranges (nothing in `dependencies`), so a host keeps one copy of each. `issues-server` no longer pins `common-entities` 5.34.0 and `tasks-entities` 1.2.3 exactly in `dependencies`; they and `issues-core`'s common/tasks dependencies are now caret peers, and every such peer has an exact `devDependencies` anchor for local builds. Adds `check-dependency-model` to CI.
