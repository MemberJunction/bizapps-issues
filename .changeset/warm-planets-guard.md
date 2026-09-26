---
"@mj-biz-apps/issues-core-entities-server": patch
---

Security hardening: strip null bytes from AppScope before inlining it as a SQL literal in the sequence-assignment batch (quote-doubling alone misses `\0`).
