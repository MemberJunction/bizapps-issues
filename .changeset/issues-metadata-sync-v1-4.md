---
'@mj-biz-apps/issues-entities': minor
---

Release seed for 1.4: `V202610231900__v1.4.x__Metadata_Sync.sql` and its PostgreSQL counterpart carry `EntityIDFieldName` on the Issues polymorphic links (AssigneeRecordID, SourceRecordID) and the user-search settings from `metadata/entities/` to hosts, which install by migration and never read `metadata/`. The predictive-escalation ML metadata is not included: its model's trained artifact file exists only on the database it was trained on.
