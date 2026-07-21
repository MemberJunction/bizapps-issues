-- ============================================================================
-- CodeGen metadata backfill (PostgreSQL only — no T-SQL counterpart)
-- ============================================================================
-- Brings __mj metadata for this app to MJ CodeGen's fixed-point state so a
-- fresh PG install is complete without running codegen, and a subsequent
-- codegen run makes no metadata changes. Mirrors the bizapps-common v5.32
-- backfill (commit 1bfe93c) and the bizapps-tasks v1.2 backfill.
--
-- Two groups of statements, all data (no DDL):
--
-- 1. SchemaInfo (MemberJunction/MJ#2992). Issues migrations never create a
--    SchemaInfo row, so on a fresh install CodeGen auto-creates one with
--    CanonicalSchemaName NULL — and the installer's own
--    PersistCanonicalSchemaName UPDATE fires BEFORE migrations, so it always
--    misses. Without the canonical name, generated class names and runtime
--    GraphQL type names come out lowercase (mjbizappsissues* instead of
--    mjBizAppsIssues*) and no longer match the published entity packages.
--    Pinned IDs for determinism. Two rows, as in the bizapps-common backfill:
--    the lowercase physical-schema row, and the canonical-cased row CodeGen
--    otherwise auto-creates on its first run (its newEntityDefaults config
--    references the schema by canonical name).
--
-- 2. EntityField normalization. The SS->PG migration converter translated
--    metadata literals into PG-flavored values (nvarchar->TEXT,
--    uniqueidentifier->UUID, sequences offset by 100000) that CodeGen
--    normalizes back on its first run. These UPDATEs ship the normalized
--    values directly. Values extracted verbatim from a post-codegen v5.44
--    database (CodeGen's fixed point on PostgreSQL). The one Description in
--    the set is CodeGen syncing IssueComment.Source's metadata to the newer
--    column comment shipped by V202606161000.
--
-- Unlike bizapps-tasks there are no GeneratedCode validator registrations to
-- pin: no CHECK-constraint validators ship in @mj-biz-apps/issues-entities
-- and none exist on the SQL Server side. On a keyless environment CodeGen's
-- constraint-parser AI call for CK_IssueNumberSequence (NextSequenceNumber)
-- fails NON-FATALLY and writes nothing, so the no-op contract holds; a keyed
-- codegen run may generate that validator (a new GeneratedCode row), exactly
-- as it would on SQL Server today.
--
-- This file is .pgonly.sql: on SQL Server none of this is needed (the schema
-- name is stored as authored and the converter never touched the metadata).
-- ============================================================================
SET standard_conforming_strings = on;

-- 1. SchemaInfo — create (fresh install) or repair (row already auto-created by CodeGen)
INSERT INTO __mj."SchemaInfo" ("ID", "SchemaName", "EntityIDMin", "EntityIDMax", "Comments", "EntityNamePrefix", "CanonicalSchemaName")
VALUES ('7683D571-7495-41B0-99CD-2E28A7475AAF', '__mj_bizappsissues', 1, 999999999, 'Auto-created by CodeGen. Please update EntityIDMin and EntityIDMax to appropriate values for this schema.', 'MJ_BizApps_Issues: ', '__mj_BizAppsIssues')
ON CONFLICT ("ID") DO NOTHING;

UPDATE __mj."SchemaInfo"
SET "CanonicalSchemaName" = '__mj_BizAppsIssues',
    "EntityNamePrefix" = COALESCE("EntityNamePrefix", 'MJ_BizApps_Issues: ')
WHERE "SchemaName" = '__mj_bizappsissues' AND "CanonicalSchemaName" IS NULL;

-- Pre-create the canonical-cased row CodeGen otherwise auto-creates (guarded by
-- SchemaName so an install where codegen already made it is left untouched)
INSERT INTO __mj."SchemaInfo" ("ID", "SchemaName", "EntityIDMin", "EntityIDMax", "Comments", "CanonicalSchemaName")
SELECT '2FB25DA4-4B5C-4E27-95D2-0198E19E2F49', '__mj_BizAppsIssues', 1, 999999999, 'Auto-created by CodeGen. Please update EntityIDMin and EntityIDMax to appropriate values for this schema.', '__mj_BizAppsIssues'
WHERE NOT EXISTS (SELECT 1 FROM __mj."SchemaInfo" WHERE "SchemaName" = '__mj_BizAppsIssues');

-- 2. EntityField normalization (CodeGen fixed-point values)
UPDATE __mj."EntityField" SET "Sequence" = 1, "Type" = 'uniqueidentifier', "DefaultColumnWidth" = 150 WHERE "ID" = 'e6f9e9bb-4c8a-45b7-94db-452b255dc1a1';
UPDATE __mj."EntityField" SET "Sequence" = 2, "Type" = 'nvarchar', "DefaultColumnWidth" = 150 WHERE "ID" = '1b4a00a6-7843-49c4-93f3-d5c13272070b';
UPDATE __mj."EntityField" SET "Sequence" = 3, "Type" = 'nvarchar', "DefaultColumnWidth" = 150 WHERE "ID" = '0e58fdbe-c30e-41c9-abc2-51de6b1bd2d6';
UPDATE __mj."EntityField" SET "Sequence" = 4, "Type" = 'nvarchar', "DefaultColumnWidth" = 150 WHERE "ID" = 'f06f4ff7-111b-407b-99f0-0b551c656f43';
UPDATE __mj."EntityField" SET "Sequence" = 5, "Type" = 'nvarchar', "DefaultColumnWidth" = 150 WHERE "ID" = 'efb68536-dc99-4f27-a77a-bf23a026ea67';
UPDATE __mj."EntityField" SET "Sequence" = 6, "Type" = 'uniqueidentifier', "DefaultColumnWidth" = 150, "RelatedEntityNameFieldMap" = 'DefaultTaskType' WHERE "ID" = '6c0b349f-4042-42b6-b8f9-b9d4a681de80';
UPDATE __mj."EntityField" SET "Sequence" = 7, "Type" = 'uniqueidentifier', "DefaultColumnWidth" = 150, "RelatedEntityNameFieldMap" = 'OnCreateAction' WHERE "ID" = '86b9ec44-d8da-4540-9638-db50f4d92bc4';
UPDATE __mj."EntityField" SET "Sequence" = 8, "Type" = 'uniqueidentifier', "DefaultColumnWidth" = 150, "RelatedEntityNameFieldMap" = 'OnStatusChangeAction' WHERE "ID" = '7d858a44-3534-468d-9e48-be4c8dc93052';
UPDATE __mj."EntityField" SET "Sequence" = 9, "Type" = 'uniqueidentifier', "DefaultColumnWidth" = 150, "RelatedEntityNameFieldMap" = 'OnAssignAction' WHERE "ID" = 'ae7027e2-994b-45ec-9f35-220a7664ab85';
UPDATE __mj."EntityField" SET "Sequence" = 10, "Type" = 'uniqueidentifier', "DefaultColumnWidth" = 150, "RelatedEntityNameFieldMap" = 'OnCloseAction' WHERE "ID" = '569d75f7-f081-4bc2-8990-321b8b9d92b6';
UPDATE __mj."EntityField" SET "Sequence" = 11, "Type" = 'bit', "DefaultColumnWidth" = 150 WHERE "ID" = '4fea107e-b189-4bad-85a6-7ecfabbf9b15';
UPDATE __mj."EntityField" SET "Sequence" = 12, "Type" = 'datetimeoffset', "DefaultColumnWidth" = 100 WHERE "ID" = 'e8f4cc38-d394-442e-a438-e30e70f07a5d';
UPDATE __mj."EntityField" SET "Sequence" = 13, "Type" = 'datetimeoffset', "DefaultColumnWidth" = 100 WHERE "ID" = 'f09b3838-633a-4b51-88ca-5ab6e5e0af5d';
UPDATE __mj."EntityField" SET "Sequence" = 14, "DefaultColumnWidth" = 150 WHERE "ID" = '9ce5a5b6-b87a-47cf-9ffc-34c433780eed';
UPDATE __mj."EntityField" SET "Sequence" = 15, "DefaultColumnWidth" = 150 WHERE "ID" = 'c8533e9d-5b23-49b4-9789-3f645f4573e4';
UPDATE __mj."EntityField" SET "Sequence" = 16, "DefaultColumnWidth" = 150 WHERE "ID" = '20b735b3-ec6a-4c5f-9027-2be6d96d9045';
UPDATE __mj."EntityField" SET "Sequence" = 17, "DefaultColumnWidth" = 150 WHERE "ID" = 'b82a5655-b11c-4ead-b7c0-cf61786a4101';
UPDATE __mj."EntityField" SET "Sequence" = 18, "DefaultColumnWidth" = 150 WHERE "ID" = 'b62c4ae2-1148-402c-accc-a4dc7354ddc0';
UPDATE __mj."EntityField" SET "Sequence" = 1, "Type" = 'uniqueidentifier', "DefaultColumnWidth" = 150 WHERE "ID" = '53331d4b-d295-4df9-a97b-9f63bce62e71';
UPDATE __mj."EntityField" SET "Sequence" = 2, "Type" = 'nvarchar', "DefaultColumnWidth" = 150 WHERE "ID" = '71b2f634-7594-490a-9bfd-d130b8193c5e';
UPDATE __mj."EntityField" SET "Sequence" = 3, "Type" = 'nvarchar', "DefaultColumnWidth" = 150 WHERE "ID" = '9487b754-90b9-42f9-ae1c-b59b0becfb2c';
UPDATE __mj."EntityField" SET "Sequence" = 4, "Type" = 'int', "DefaultColumnWidth" = 50 WHERE "ID" = 'da13598b-b481-48a7-969d-ac8cc80af61a';
UPDATE __mj."EntityField" SET "Sequence" = 5, "Type" = 'bit', "DefaultColumnWidth" = 150 WHERE "ID" = 'e66776d3-0318-4c92-b30a-373fb4d64d9d';
UPDATE __mj."EntityField" SET "Sequence" = 6, "Type" = 'bit', "DefaultColumnWidth" = 150 WHERE "ID" = '04aa5244-2c13-4768-826b-94f72805efd5';
UPDATE __mj."EntityField" SET "Sequence" = 7, "Type" = 'nvarchar', "DefaultColumnWidth" = 150 WHERE "ID" = '796866ab-7cae-4ce7-9e17-2b7a38e86639';
UPDATE __mj."EntityField" SET "Sequence" = 8, "Type" = 'datetimeoffset', "DefaultColumnWidth" = 100 WHERE "ID" = '29e0d51a-6e88-44f6-b2c5-6156bc4fafca';
UPDATE __mj."EntityField" SET "Sequence" = 9, "Type" = 'datetimeoffset', "DefaultColumnWidth" = 100 WHERE "ID" = 'a40692e4-de3e-41bf-acbd-d1cb45d4d1ab';
UPDATE __mj."EntityField" SET "Sequence" = 10, "Type" = 'bit', "DefaultColumnWidth" = 150 WHERE "ID" = 'ecdec461-5ee5-4e31-910f-8e4a313a8a05';
UPDATE __mj."EntityField" SET "Sequence" = 21, "DefaultColumnWidth" = 150 WHERE "ID" = 'a0e546ec-bea3-46e0-b5e9-21c9f6a31ae3';
UPDATE __mj."EntityField" SET "Sequence" = 1, "Type" = 'uniqueidentifier', "DefaultColumnWidth" = 150 WHERE "ID" = 'd3cf7eac-3527-47dd-87dd-da8744cda808';
UPDATE __mj."EntityField" SET "Sequence" = 3, "Type" = 'nvarchar', "DefaultColumnWidth" = 150 WHERE "ID" = 'fbda77b7-3edb-4d32-a7d4-06fe401457be';
UPDATE __mj."EntityField" SET "Sequence" = 4, "Type" = 'nvarchar', "DefaultColumnWidth" = 150 WHERE "ID" = '1ce66015-9e1b-4e20-be02-922d1d91a619';
UPDATE __mj."EntityField" SET "Sequence" = 6, "Type" = 'uniqueidentifier', "DefaultColumnWidth" = 150, "RelatedEntityNameFieldMap" = 'Status' WHERE "ID" = '2963d2bc-0473-47a0-be0a-0e1bd925928b';
UPDATE __mj."EntityField" SET "Sequence" = 7, "Type" = 'nvarchar', "DefaultColumnWidth" = 150 WHERE "ID" = '99c48bc4-c15e-440a-a577-ec5ba8f9e48b';
UPDATE __mj."EntityField" SET "Sequence" = 8, "Type" = 'nvarchar', "DefaultColumnWidth" = 150 WHERE "ID" = '7c48ec27-0691-4ce9-b990-f554caf50864';
UPDATE __mj."EntityField" SET "Sequence" = 9, "Type" = 'uniqueidentifier', "DefaultColumnWidth" = 150, "RelatedEntityNameFieldMap" = 'ReporterPerson' WHERE "ID" = '06ed94d8-4607-4061-888e-788ffafca023';
UPDATE __mj."EntityField" SET "Sequence" = 10, "Type" = 'nvarchar', "DefaultColumnWidth" = 150 WHERE "ID" = '65c94b3c-a5bf-4d2d-bbff-289a0c041047';
UPDATE __mj."EntityField" SET "Sequence" = 11, "Type" = 'uniqueidentifier', "DefaultColumnWidth" = 150, "RelatedEntityNameFieldMap" = 'AssigneeEntity' WHERE "ID" = '5d649c62-6589-43f0-affd-e3f9e3268cc8';
UPDATE __mj."EntityField" SET "Sequence" = 12, "Type" = 'nvarchar', "DefaultColumnWidth" = 150 WHERE "ID" = '24653d3b-faed-4a91-bd7f-8c903b8ad018';
UPDATE __mj."EntityField" SET "Sequence" = 13, "Type" = 'uniqueidentifier', "DefaultColumnWidth" = 150, "RelatedEntityNameFieldMap" = 'SourceEntity' WHERE "ID" = '9d602c66-9fb5-4514-9ed6-7b530012ae3a';
UPDATE __mj."EntityField" SET "Sequence" = 14, "Type" = 'nvarchar', "DefaultColumnWidth" = 150 WHERE "ID" = '5e4d5272-5f71-4e7f-99b0-f0d9de5c3641';
UPDATE __mj."EntityField" SET "Sequence" = 16, "Type" = 'datetimeoffset', "DefaultColumnWidth" = 100 WHERE "ID" = 'd50b709a-c90f-4771-abef-9a108002a341';
UPDATE __mj."EntityField" SET "Sequence" = 17, "Type" = 'datetimeoffset', "DefaultColumnWidth" = 100 WHERE "ID" = '9ab132e0-fb1a-410a-a736-ddfbb0388f7e';
UPDATE __mj."EntityField" SET "Sequence" = 18, "Type" = 'uniqueidentifier', "DefaultColumnWidth" = 150, "RelatedEntityNameFieldMap" = 'CreatedByPerson' WHERE "ID" = '2bdfb21a-baf7-482d-98c5-4dfd03ff45ee';
UPDATE __mj."EntityField" SET "Sequence" = 19, "Type" = 'datetimeoffset', "DefaultColumnWidth" = 100 WHERE "ID" = 'd6995810-5f0a-4775-8e81-9bd304dca9e0';
UPDATE __mj."EntityField" SET "Sequence" = 20, "Type" = 'datetimeoffset', "DefaultColumnWidth" = 100 WHERE "ID" = '77f34775-1c61-4921-ac99-045d0a20b9bf';
UPDATE __mj."EntityField" SET "Sequence" = 22, "DefaultColumnWidth" = 150 WHERE "ID" = '9111e30e-76a3-4582-ac5c-06a7b9ac530e';
UPDATE __mj."EntityField" SET "Sequence" = 23, "DefaultColumnWidth" = 150 WHERE "ID" = '5b543630-4c16-4034-99de-1c4420a9cbd2';
UPDATE __mj."EntityField" SET "Sequence" = 24, "DefaultColumnWidth" = 150 WHERE "ID" = '00d07775-578d-4f35-86b6-136b9256fc30';
UPDATE __mj."EntityField" SET "Sequence" = 25, "DefaultColumnWidth" = 150 WHERE "ID" = 'd0d423b1-0148-4920-a657-5756b13364b6';
UPDATE __mj."EntityField" SET "Sequence" = 26, "DefaultColumnWidth" = 150 WHERE "ID" = '7d7c497f-a10e-4ea5-8daf-50095c9fb635';
UPDATE __mj."EntityField" SET "Sequence" = 5, "Type" = 'uniqueidentifier', "DefaultColumnWidth" = 150, "RelatedEntityNameFieldMap" = 'IssueType' WHERE "ID" = 'e4408976-8a26-42d6-9b2d-81216476ad9c';
UPDATE __mj."EntityField" SET "Sequence" = 2, "Type" = 'nvarchar', "DefaultColumnWidth" = 150 WHERE "ID" = 'adddcc67-6c31-4e40-8c22-aaaf2e9eb165';
UPDATE __mj."EntityField" SET "Sequence" = 15, "Type" = 'nvarchar', "DefaultColumnWidth" = 150 WHERE "ID" = 'bdc175d9-3f7b-4818-af86-801d821b9276';
UPDATE __mj."EntityField" SET "Sequence" = 1, "Type" = 'uniqueidentifier', "DefaultColumnWidth" = 150 WHERE "ID" = '56419321-e23c-44ae-92e5-60060382f4fa';
UPDATE __mj."EntityField" SET "Sequence" = 2, "Type" = 'uniqueidentifier', "DefaultColumnWidth" = 150 WHERE "ID" = 'bb65e98f-c7c3-41bc-a268-5added0d5f5f';
UPDATE __mj."EntityField" SET "Sequence" = 3, "Type" = 'nvarchar', "DefaultColumnWidth" = 150 WHERE "ID" = '4fb78308-1867-468d-916a-8118960e8c55';
UPDATE __mj."EntityField" SET "Sequence" = 5, "Type" = 'nvarchar', "DefaultColumnWidth" = 150 WHERE "ID" = '0b6ee56c-7364-491f-bc0b-de8b0d69d271';
UPDATE __mj."EntityField" SET "Sequence" = 6, "Description" = 'Direction/visibility of the comment (channel-agnostic): ''internal'' (staff-only note, never sent), ''outbound'' (customer-facing message we sent, on any channel), or ''inbound'' (a message from the customer/external side captured into the thread). The delivery channel is knowable from the ticket''s linked message, not here.', "Type" = 'nvarchar', "DefaultColumnWidth" = 150 WHERE "ID" = '89d0ecae-49f6-4730-b9e4-1f0cfe373571';
UPDATE __mj."EntityField" SET "Sequence" = 7, "Type" = 'datetimeoffset', "DefaultColumnWidth" = 100 WHERE "ID" = 'ef200acb-07a0-44be-9c7a-d14f4a72dcd2';
UPDATE __mj."EntityField" SET "Sequence" = 8, "Type" = 'datetimeoffset', "DefaultColumnWidth" = 100 WHERE "ID" = '84fda08a-9365-4e56-8129-9808d2de19cd';
UPDATE __mj."EntityField" SET "Sequence" = 9, "DefaultColumnWidth" = 150 WHERE "ID" = 'f85bce40-59bb-42d8-8bb6-971c6479ba73';
UPDATE __mj."EntityField" SET "Sequence" = 4, "Type" = 'uniqueidentifier', "DefaultColumnWidth" = 150, "RelatedEntityNameFieldMap" = 'AuthorPerson' WHERE "ID" = '31762b00-ece7-4760-ac10-b11d53793fbc';
UPDATE __mj."EntityField" SET "Sequence" = 3, "Type" = 'datetimeoffset', "DefaultColumnWidth" = 100 WHERE "ID" = 'ee76be39-ba96-4c56-849b-d92c27504b43';
UPDATE __mj."EntityField" SET "Sequence" = 1, "Type" = 'nvarchar', "DefaultColumnWidth" = 150 WHERE "ID" = '3737e78f-3cab-49cf-ab9e-635da764e876';
UPDATE __mj."EntityField" SET "Sequence" = 4, "Type" = 'datetimeoffset', "DefaultColumnWidth" = 100 WHERE "ID" = '30118bfc-fe8a-4fe4-903c-79184edce894';
UPDATE __mj."EntityField" SET "Sequence" = 2, "Type" = 'int', "DefaultColumnWidth" = 50 WHERE "ID" = '219d0d34-f277-4222-b9a1-f5a9f155abca';

-- NOTE — deliberately NOT shipped here: the four GRANT EXECUTE ... TO cdp_UI
-- statements CodeGen derives from the UI role's CanCreate/CanUpdate permissions
-- (spCreateIssue / spUpdateIssue / spCreateIssueComment / spUpdateIssueComment).
-- The SQL Server migrations do not carry them either — DB-level proc grants are
-- CodeGen output and ship in the next CodeGen_Run migration on BOTH platforms.
-- Hand-adding them on PG only would break migration parity with SQL Server.
