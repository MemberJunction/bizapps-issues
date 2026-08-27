---
"@mj-biz-apps/issues-entities": minor
"@mj-biz-apps/issues-ng": patch
---

Declare `@memberjunction/ng-shared` as a peer of issues-ng — the section resources import `BaseResourceComponent` from it, and under a strict pnpm layout the undeclared module doesn't resolve and `ngc` fails. Ship the v1.2.x metadata sync migration so a migrations-only install carries the Issues application record, its application roles, and the form-chrome placements with no `mj sync push` required.
