---
"@mj-biz-apps/issues-core-entities-server": patch
---

Security hardening: `SequenceService` now escapes the `AppScope` SQL literal with `EscapeSQLString` from `@memberjunction/global` (which also strips null bytes) instead of a hand-rolled `.replace(/'/g, "''")`, on both the SQL Server and PostgreSQL builders. `IssueEntityServer.fireHook` gained a comment warning hook-action authors that the forwarded issue fields are untrusted input.
