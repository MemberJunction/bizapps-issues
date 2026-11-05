---
"@mj-biz-apps/issues-ng": minor
"@mj-biz-apps/issues-core": minor
"@mj-biz-apps/issues-server": minor
---

Drop the unused `@memberjunction/actions-base` peer from `@mj-biz-apps/issues-ng` and move sibling app packages (`@mj-biz-apps/common-entities`, `@mj-biz-apps/tasks-entities`) to `peerDependencies` with `devDependencies` build anchors in `@mj-biz-apps/issues-core` and `@mj-biz-apps/issues-server` so the family dependency and manifest-tier guard passes cleanly.
