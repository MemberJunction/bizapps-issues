-- ============================================================================
-- MemberJunction PostgreSQL Migration
-- Converted from SQL Server using TypeScript conversion pipeline
-- ============================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Schema
CREATE SCHEMA IF NOT EXISTS "__mj_BizAppsIssues";
SET search_path TO "__mj_BizAppsIssues", public;

-- Ensure backslashes in string literals are treated literally (not as escape sequences)
SET standard_conforming_strings = on;

-- NOTE: Earlier converter versions made INTEGER to BOOLEAN cast implicit by
-- modifying the system catalog so SS-style INSERT INTO bool_col VALUES (1)
-- would work. That modification required pg_catalog write privileges, which
-- managed PG (RDS, Aurora, Cloud SQL, Azure) does not grant. As of v5.30 all
-- bulk INSERTs are emitted with native TRUE/FALSE values directly, so the
-- cast modification is no longer needed. Removed to support managed-PG
-- installs out of the box.


-- ===================== DDL: Tables, PKs, Indexes =====================

-- =============================================================================
-- 2. TABLES (created without foreign keys; FKs added in section 3)
-- =============================================================================

---------------------------------------------------------------------------
-- 2.1 IssueType — lifecycle automation for a class of issue. Mirrors
-- bizapps-tasks' TaskType action-hook pattern: each On*ActionID points at
-- a ${mjSchema}.[Action] fired by IssueService at the matching lifecycle
-- event. DefaultTaskTypeID is the bizapps-tasks TaskType used when an Issue
-- of this type spawns work via IssueWorkService.
---------------------------------------------------------------------------
CREATE TABLE "__mj_BizAppsIssues"."IssueType" (
 "ID" UUID NOT NULL DEFAULT gen_random_uuid(),
 "Name" VARCHAR(100) NOT NULL,
 "Description" TEXT NULL,
 "IconClass" VARCHAR(100) NULL,
 "DefaultPriority" VARCHAR(20) NOT NULL DEFAULT 'Medium',
 "DefaultTaskTypeID" UUID NULL,
 "OnCreateActionID" UUID NULL,
 "OnStatusChangeActionID" UUID NULL,
 "OnAssignActionID" UUID NULL,
 "OnCloseActionID" UUID NULL,
 "IsActive" BOOLEAN NOT NULL DEFAULT TRUE,
 CONSTRAINT PK_IssueType PRIMARY KEY ("ID"),
 CONSTRAINT UQ_IssueType_Name UNIQUE ("Name"),
 CONSTRAINT CK_IssueType_DefaultPriority CHECK ("DefaultPriority" IN ('Low', 'Medium', 'High', 'Critical'))
);

---------------------------------------------------------------------------
-- 2.2 IssueStatus — workflow states (seeded via metadata, not here). Drives
-- board columns later. IsDefault marks the new-issue status; IsTerminal
-- marks closed/resolved end states.
---------------------------------------------------------------------------
CREATE TABLE "__mj_BizAppsIssues"."IssueStatus" (
 "ID" UUID NOT NULL DEFAULT gen_random_uuid(),
 "Name" VARCHAR(100) NOT NULL,
 "Description" TEXT NULL,
 "Sequence" INTEGER NOT NULL DEFAULT 100,
 "IsDefault" BOOLEAN NOT NULL DEFAULT FALSE,
 "IsTerminal" BOOLEAN NOT NULL DEFAULT FALSE,
 "ColorCode" VARCHAR(20) NULL,
 CONSTRAINT PK_IssueStatus PRIMARY KEY ("ID"),
 CONSTRAINT UQ_IssueStatus_Name UNIQUE ("Name")
);

---------------------------------------------------------------------------
-- 2.3 Issue — the core case / ticket / feedback record.
-- - Reporter: ReporterPersonID (nullable — external reporters may not exist
-- as a Person) plus ReporterEmail for anonymous/external sources.
-- - Polymorphic assignee (pattern from TaskAssignment): a Person OR an AI
-- Agent, addressed by AssigneeEntityID + AssigneeRecordID.
-- - Polymorphic source: WHAT the issue is about — any record in the system,
-- addressed by SourceEntityID + SourceRecordID.
-- - Severity = impact, Priority = scheduling (kept distinct per decision).
---------------------------------------------------------------------------
CREATE TABLE "__mj_BizAppsIssues"."Issue" (
 "ID" UUID NOT NULL DEFAULT gen_random_uuid(),
 "IssueNumber" VARCHAR(50) NULL,
 "Title" VARCHAR(500) NOT NULL,
 "Description" TEXT NULL,
 "IssueTypeID" UUID NOT NULL,
 "StatusID" UUID NOT NULL,
 "Severity" VARCHAR(20) NOT NULL DEFAULT 'Medium',
 "Priority" VARCHAR(20) NOT NULL DEFAULT 'Medium',
 "ReporterPersonID" UUID NULL,
 "ReporterEmail" VARCHAR(320) NULL,
 "AssigneeEntityID" UUID NULL,
 "AssigneeRecordID" VARCHAR(450) NULL,
 "SourceEntityID" UUID NULL,
 "SourceRecordID" VARCHAR(450) NULL,
 "AppScope" VARCHAR(255) NULL,
 "ResolvedAt" TIMESTAMPTZ NULL,
 "ClosedAt" TIMESTAMPTZ NULL,
 "CreatedByPersonID" UUID NULL,
 CONSTRAINT PK_Issue PRIMARY KEY ("ID"),
 CONSTRAINT UQ_Issue_IssueNumber UNIQUE ("IssueNumber"),
 CONSTRAINT CK_Issue_Severity CHECK ("Severity" IN ('Low', 'Medium', 'High', 'Critical')),
 CONSTRAINT CK_Issue_Priority CHECK ("Priority" IN ('Low', 'Medium', 'High', 'Critical')),
 -- Polymorphic columns are all-or-nothing: an entity reference without a
 -- record id (or vice versa) is a data error.
 CONSTRAINT CK_Issue_Assignee CHECK (
 ("AssigneeEntityID" IS NULL AND "AssigneeRecordID" IS NULL) OR
 ("AssigneeEntityID" IS NOT NULL AND "AssigneeRecordID" IS NOT NULL)
 ),
 CONSTRAINT CK_Issue_Source CHECK (
 ("SourceEntityID" IS NULL AND "SourceRecordID" IS NULL) OR
 ("SourceEntityID" IS NOT NULL AND "SourceRecordID" IS NOT NULL)
 )
);

---------------------------------------------------------------------------
-- 2.4 IssueComment — threaded discussion on an Issue. Author is a Person when
-- internal; AuthorEmail carries the address for email/external sources.
-- Source 'external' is reserved for v1.1 provider sync.
---------------------------------------------------------------------------
CREATE TABLE "__mj_BizAppsIssues"."IssueComment" (
 "ID" UUID NOT NULL DEFAULT gen_random_uuid(),
 "IssueID" UUID NOT NULL,
 "Body" TEXT NOT NULL,
 "AuthorPersonID" UUID NULL,
 "AuthorEmail" VARCHAR(320) NULL,
 "Source" VARCHAR(20) NOT NULL DEFAULT 'internal',
 CONSTRAINT PK_IssueComment PRIMARY KEY ("ID"),
 CONSTRAINT CK_IssueComment_Source CHECK ("Source" IN ('internal', 'email', 'external'))
);

---------------------------------------------------------------------------
-- 2.5 IssueNumberSequence — per-scope gap-free counter backing the
-- human-readable Issue."IssueNumber". ScopeCode is the NORMALIZED
-- (trimmed/uppercased) AppScope, or 'ISS' when an issue has no AppScope.
-- Maintained ONLY by spAssignNextIssueNumber — never write directly.
---------------------------------------------------------------------------
CREATE TABLE "__mj_BizAppsIssues"."IssueNumberSequence" (
 "ScopeCode" VARCHAR(50) NOT NULL,
 "NextSequenceNumber" INTEGER NOT NULL DEFAULT 1,
 CONSTRAINT PK_IssueNumberSequence PRIMARY KEY ("ScopeCode"),
 CONSTRAINT CK_IssueNumberSequence_NextSeq CHECK ("NextSequenceNumber" > 0)
);

ALTER TABLE "__mj_BizAppsIssues"."Issue"
 ADD COLUMN IF NOT EXISTS "__mj_CreatedAt" TIMESTAMPTZ NULL;

/* SQL text to add special date field __mj_UpdatedAt to entity "__mj_BizAppsIssues"."Issue" */
ALTER TABLE "__mj_BizAppsIssues"."Issue"
 ADD COLUMN IF NOT EXISTS "__mj_UpdatedAt" TIMESTAMPTZ NULL;

/* SQL text to add special date field __mj_CreatedAt to entity "__mj_BizAppsIssues"."IssueNumberSequence" */
ALTER TABLE "__mj_BizAppsIssues"."IssueNumberSequence"
 ADD COLUMN IF NOT EXISTS "__mj_CreatedAt" TIMESTAMPTZ NULL;

/* SQL text to add special date field __mj_UpdatedAt to entity "__mj_BizAppsIssues"."IssueNumberSequence" */
ALTER TABLE "__mj_BizAppsIssues"."IssueNumberSequence"
 ADD COLUMN IF NOT EXISTS "__mj_UpdatedAt" TIMESTAMPTZ NULL;

/* SQL text to add special date field __mj_CreatedAt to entity "__mj_BizAppsIssues"."IssueStatus" */
ALTER TABLE "__mj_BizAppsIssues"."IssueStatus"
 ADD COLUMN IF NOT EXISTS "__mj_CreatedAt" TIMESTAMPTZ NULL;

/* SQL text to add special date field __mj_UpdatedAt to entity "__mj_BizAppsIssues"."IssueStatus" */
ALTER TABLE "__mj_BizAppsIssues"."IssueStatus"
 ADD COLUMN IF NOT EXISTS "__mj_UpdatedAt" TIMESTAMPTZ NULL;

/* SQL text to add special date field __mj_CreatedAt to entity "__mj_BizAppsIssues"."IssueType" */
ALTER TABLE "__mj_BizAppsIssues"."IssueType"
 ADD COLUMN IF NOT EXISTS "__mj_CreatedAt" TIMESTAMPTZ NULL;

/* SQL text to add special date field __mj_UpdatedAt to entity "__mj_BizAppsIssues"."IssueType" */
ALTER TABLE "__mj_BizAppsIssues"."IssueType"
 ADD COLUMN IF NOT EXISTS "__mj_UpdatedAt" TIMESTAMPTZ NULL;

/* SQL text to add special date field __mj_CreatedAt to entity "__mj_BizAppsIssues"."IssueComment" */
ALTER TABLE "__mj_BizAppsIssues"."IssueComment"
 ADD COLUMN IF NOT EXISTS "__mj_CreatedAt" TIMESTAMPTZ NULL;

/* SQL text to add special date field __mj_UpdatedAt to entity "__mj_BizAppsIssues"."IssueComment" */
ALTER TABLE "__mj_BizAppsIssues"."IssueComment"
 ADD COLUMN IF NOT EXISTS "__mj_UpdatedAt" TIMESTAMPTZ NULL;

CREATE INDEX IF NOT EXISTS "IDX_AUTO_MJ_FKEY_IssueComment_IssueID" ON "__mj_BizAppsIssues"."IssueComment" ("IssueID");

CREATE INDEX IF NOT EXISTS "IDX_AUTO_MJ_FKEY_IssueComment_AuthorPersonID" ON "__mj_BizAppsIssues"."IssueComment" ("AuthorPersonID");

CREATE INDEX IF NOT EXISTS "IDX_AUTO_MJ_FKEY_IssueType_DefaultTaskTypeID" ON "__mj_BizAppsIssues"."IssueType" ("DefaultTaskTypeID");

CREATE INDEX IF NOT EXISTS "IDX_AUTO_MJ_FKEY_IssueType_OnCreateActionID" ON "__mj_BizAppsIssues"."IssueType" ("OnCreateActionID");

CREATE INDEX IF NOT EXISTS "IDX_AUTO_MJ_FKEY_IssueType_OnStatusChangeActionID" ON "__mj_BizAppsIssues"."IssueType" ("OnStatusChangeActionID");

CREATE INDEX IF NOT EXISTS "IDX_AUTO_MJ_FKEY_IssueType_OnAssignActionID" ON "__mj_BizAppsIssues"."IssueType" ("OnAssignActionID");

CREATE INDEX IF NOT EXISTS "IDX_AUTO_MJ_FKEY_IssueType_OnCloseActionID" ON "__mj_BizAppsIssues"."IssueType" ("OnCloseActionID");

CREATE INDEX IF NOT EXISTS "IDX_AUTO_MJ_FKEY_Issue_IssueTypeID" ON "__mj_BizAppsIssues"."Issue" ("IssueTypeID");

CREATE INDEX IF NOT EXISTS "IDX_AUTO_MJ_FKEY_Issue_StatusID" ON "__mj_BizAppsIssues"."Issue" ("StatusID");

CREATE INDEX IF NOT EXISTS "IDX_AUTO_MJ_FKEY_Issue_ReporterPersonID" ON "__mj_BizAppsIssues"."Issue" ("ReporterPersonID");

CREATE INDEX IF NOT EXISTS "IDX_AUTO_MJ_FKEY_Issue_AssigneeEntityID" ON "__mj_BizAppsIssues"."Issue" ("AssigneeEntityID");

CREATE INDEX IF NOT EXISTS "IDX_AUTO_MJ_FKEY_Issue_SourceEntityID" ON "__mj_BizAppsIssues"."Issue" ("SourceEntityID");

CREATE INDEX IF NOT EXISTS "IDX_AUTO_MJ_FKEY_Issue_CreatedByPersonID" ON "__mj_BizAppsIssues"."Issue" ("CreatedByPersonID");


-- ===================== Views =====================

DROP VIEW IF EXISTS "__mj_BizAppsIssues"."vwIssueNumberSequences" CASCADE;
DO $do$
DECLARE
  v_target_schema CONSTANT TEXT := '__mj_BizAppsIssues';
  v_target_name CONSTANT TEXT := 'vwIssueNumberSequences';
  vsql CONSTANT TEXT := $vsql$CREATE OR REPLACE VIEW "__mj_BizAppsIssues"."vwIssueNumberSequences"
AS SELECT
    i.*
FROM
    "__mj_BizAppsIssues"."IssueNumberSequence" AS i$vsql$;
  v_target_oid OID;
  v_dep RECORD;
  v_captured JSONB[] := ARRAY[]::JSONB[];
  v_n INTEGER;
BEGIN
  EXECUTE vsql;
EXCEPTION WHEN invalid_table_definition THEN
  -- Column list changed; need CASCADE. Preserve dependent views first.
  SELECT c.oid INTO v_target_oid
  FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid
  WHERE n.nspname = v_target_schema AND c.relname = v_target_name AND c.relkind = 'v';
  IF v_target_oid IS NOT NULL THEN
    FOR v_dep IN
      WITH RECURSIVE deps AS (
        SELECT c.oid, c.relname AS name, n.nspname AS schema, 1 AS depth
        FROM pg_rewrite r
        JOIN pg_depend d ON d.objid = r.oid
        JOIN pg_class c ON c.oid = r.ev_class
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE d.refobjid = v_target_oid AND d.deptype = 'n'
          AND c.oid <> v_target_oid AND c.relkind = 'v'
        UNION
        SELECT c.oid, c.relname, n.nspname, p.depth + 1
        FROM deps p
        JOIN pg_rewrite r ON TRUE
        JOIN pg_depend d ON d.objid = r.oid AND d.refobjid = p.oid
        JOIN pg_class c ON c.oid = r.ev_class
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE c.relkind = 'v' AND c.oid <> p.oid
      )
      SELECT oid, name, schema, MAX(depth) AS max_depth,
             pg_catalog.pg_get_viewdef(oid, true) AS viewdef
      FROM deps GROUP BY oid, name, schema
      ORDER BY MAX(depth) ASC
    LOOP
      v_captured := v_captured || jsonb_build_object(
        'schema', v_dep.schema, 'name', v_dep.name, 'def', v_dep.viewdef);
    END LOOP;
  END IF;
  EXECUTE format('DROP VIEW IF EXISTS %I.%I CASCADE', v_target_schema, v_target_name);
  EXECUTE vsql;
  IF v_captured IS NOT NULL AND array_length(v_captured, 1) > 0 THEN
    FOR v_n IN 1..array_length(v_captured, 1) LOOP
      BEGIN
        EXECUTE format('CREATE VIEW %I.%I AS %s',
          v_captured[v_n]->>'schema', v_captured[v_n]->>'name', v_captured[v_n]->>'def');
      EXCEPTION WHEN others THEN
        RAISE WARNING 'Could not restore dependent view %.%: %',
          v_captured[v_n]->>'schema', v_captured[v_n]->>'name', SQLERRM;
      END;
    END LOOP;
  END IF;
END;
$do$;

DROP VIEW IF EXISTS "__mj_BizAppsIssues"."vwIssueStatus" CASCADE;
DO $do$
DECLARE
  v_target_schema CONSTANT TEXT := '__mj_BizAppsIssues';
  v_target_name CONSTANT TEXT := 'vwIssueStatus';
  vsql CONSTANT TEXT := $vsql$CREATE OR REPLACE VIEW "__mj_BizAppsIssues"."vwIssueStatus"
AS SELECT
    i.*
FROM
    "__mj_BizAppsIssues"."IssueStatus" AS i$vsql$;
  v_target_oid OID;
  v_dep RECORD;
  v_captured JSONB[] := ARRAY[]::JSONB[];
  v_n INTEGER;
BEGIN
  EXECUTE vsql;
EXCEPTION WHEN invalid_table_definition THEN
  -- Column list changed; need CASCADE. Preserve dependent views first.
  SELECT c.oid INTO v_target_oid
  FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid
  WHERE n.nspname = v_target_schema AND c.relname = v_target_name AND c.relkind = 'v';
  IF v_target_oid IS NOT NULL THEN
    FOR v_dep IN
      WITH RECURSIVE deps AS (
        SELECT c.oid, c.relname AS name, n.nspname AS schema, 1 AS depth
        FROM pg_rewrite r
        JOIN pg_depend d ON d.objid = r.oid
        JOIN pg_class c ON c.oid = r.ev_class
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE d.refobjid = v_target_oid AND d.deptype = 'n'
          AND c.oid <> v_target_oid AND c.relkind = 'v'
        UNION
        SELECT c.oid, c.relname, n.nspname, p.depth + 1
        FROM deps p
        JOIN pg_rewrite r ON TRUE
        JOIN pg_depend d ON d.objid = r.oid AND d.refobjid = p.oid
        JOIN pg_class c ON c.oid = r.ev_class
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE c.relkind = 'v' AND c.oid <> p.oid
      )
      SELECT oid, name, schema, MAX(depth) AS max_depth,
             pg_catalog.pg_get_viewdef(oid, true) AS viewdef
      FROM deps GROUP BY oid, name, schema
      ORDER BY MAX(depth) ASC
    LOOP
      v_captured := v_captured || jsonb_build_object(
        'schema', v_dep.schema, 'name', v_dep.name, 'def', v_dep.viewdef);
    END LOOP;
  END IF;
  EXECUTE format('DROP VIEW IF EXISTS %I.%I CASCADE', v_target_schema, v_target_name);
  EXECUTE vsql;
  IF v_captured IS NOT NULL AND array_length(v_captured, 1) > 0 THEN
    FOR v_n IN 1..array_length(v_captured, 1) LOOP
      BEGIN
        EXECUTE format('CREATE VIEW %I.%I AS %s',
          v_captured[v_n]->>'schema', v_captured[v_n]->>'name', v_captured[v_n]->>'def');
      EXCEPTION WHEN others THEN
        RAISE WARNING 'Could not restore dependent view %.%: %',
          v_captured[v_n]->>'schema', v_captured[v_n]->>'name', SQLERRM;
      END;
    END LOOP;
  END IF;
END;
$do$;

DROP VIEW IF EXISTS "__mj_BizAppsIssues"."vwIssueComments" CASCADE;
DO $do$
DECLARE
  v_target_schema CONSTANT TEXT := '__mj_BizAppsIssues';
  v_target_name CONSTANT TEXT := 'vwIssueComments';
  vsql CONSTANT TEXT := $vsql$CREATE OR REPLACE VIEW "__mj_BizAppsIssues"."vwIssueComments"
AS SELECT
    i.*,
    "mjBizAppsCommonPerson_AuthorPersonID"."DisplayName" AS "AuthorPerson"
FROM
    "__mj_BizAppsIssues"."IssueComment" AS i
LEFT OUTER JOIN
    "${mjSchema}_BizAppsCommon"."Person" AS "mjBizAppsCommonPerson_AuthorPersonID"
  ON
    i."AuthorPersonID" = "mjBizAppsCommonPerson_AuthorPersonID"."ID"$vsql$;
  v_target_oid OID;
  v_dep RECORD;
  v_captured JSONB[] := ARRAY[]::JSONB[];
  v_n INTEGER;
BEGIN
  EXECUTE vsql;
EXCEPTION WHEN invalid_table_definition THEN
  -- Column list changed; need CASCADE. Preserve dependent views first.
  SELECT c.oid INTO v_target_oid
  FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid
  WHERE n.nspname = v_target_schema AND c.relname = v_target_name AND c.relkind = 'v';
  IF v_target_oid IS NOT NULL THEN
    FOR v_dep IN
      WITH RECURSIVE deps AS (
        SELECT c.oid, c.relname AS name, n.nspname AS schema, 1 AS depth
        FROM pg_rewrite r
        JOIN pg_depend d ON d.objid = r.oid
        JOIN pg_class c ON c.oid = r.ev_class
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE d.refobjid = v_target_oid AND d.deptype = 'n'
          AND c.oid <> v_target_oid AND c.relkind = 'v'
        UNION
        SELECT c.oid, c.relname, n.nspname, p.depth + 1
        FROM deps p
        JOIN pg_rewrite r ON TRUE
        JOIN pg_depend d ON d.objid = r.oid AND d.refobjid = p.oid
        JOIN pg_class c ON c.oid = r.ev_class
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE c.relkind = 'v' AND c.oid <> p.oid
      )
      SELECT oid, name, schema, MAX(depth) AS max_depth,
             pg_catalog.pg_get_viewdef(oid, true) AS viewdef
      FROM deps GROUP BY oid, name, schema
      ORDER BY MAX(depth) ASC
    LOOP
      v_captured := v_captured || jsonb_build_object(
        'schema', v_dep.schema, 'name', v_dep.name, 'def', v_dep.viewdef);
    END LOOP;
  END IF;
  EXECUTE format('DROP VIEW IF EXISTS %I.%I CASCADE', v_target_schema, v_target_name);
  EXECUTE vsql;
  IF v_captured IS NOT NULL AND array_length(v_captured, 1) > 0 THEN
    FOR v_n IN 1..array_length(v_captured, 1) LOOP
      BEGIN
        EXECUTE format('CREATE VIEW %I.%I AS %s',
          v_captured[v_n]->>'schema', v_captured[v_n]->>'name', v_captured[v_n]->>'def');
      EXCEPTION WHEN others THEN
        RAISE WARNING 'Could not restore dependent view %.%: %',
          v_captured[v_n]->>'schema', v_captured[v_n]->>'name', SQLERRM;
      END;
    END LOOP;
  END IF;
END;
$do$;

DROP VIEW IF EXISTS "__mj_BizAppsIssues"."vwIssueTypes" CASCADE;
DO $do$
DECLARE
  v_target_schema CONSTANT TEXT := '__mj_BizAppsIssues';
  v_target_name CONSTANT TEXT := 'vwIssueTypes';
  vsql CONSTANT TEXT := $vsql$CREATE OR REPLACE VIEW "__mj_BizAppsIssues"."vwIssueTypes"
AS SELECT
    i.*,
    "mjBizAppsTasksTaskType_DefaultTaskTypeID"."Name" AS "DefaultTaskType",
    "MJAction_OnCreateActionID"."Name" AS "OnCreateAction",
    "MJAction_OnStatusChangeActionID"."Name" AS "OnStatusChangeAction",
    "MJAction_OnAssignActionID"."Name" AS "OnAssignAction",
    "MJAction_OnCloseActionID"."Name" AS "OnCloseAction"
FROM
    "__mj_BizAppsIssues"."IssueType" AS i
LEFT OUTER JOIN
    "${mjSchema}_BizAppsTasks"."TaskType" AS "mjBizAppsTasksTaskType_DefaultTaskTypeID"
  ON
    i."DefaultTaskTypeID" = "mjBizAppsTasksTaskType_DefaultTaskTypeID"."ID"
LEFT OUTER JOIN
    "${mjSchema}"."Action" AS "MJAction_OnCreateActionID"
  ON
    i."OnCreateActionID" = "MJAction_OnCreateActionID"."ID"
LEFT OUTER JOIN
    "${mjSchema}"."Action" AS "MJAction_OnStatusChangeActionID"
  ON
    i."OnStatusChangeActionID" = "MJAction_OnStatusChangeActionID"."ID"
LEFT OUTER JOIN
    "${mjSchema}"."Action" AS "MJAction_OnAssignActionID"
  ON
    i."OnAssignActionID" = "MJAction_OnAssignActionID"."ID"
LEFT OUTER JOIN
    "${mjSchema}"."Action" AS "MJAction_OnCloseActionID"
  ON
    i."OnCloseActionID" = "MJAction_OnCloseActionID"."ID"$vsql$;
  v_target_oid OID;
  v_dep RECORD;
  v_captured JSONB[] := ARRAY[]::JSONB[];
  v_n INTEGER;
BEGIN
  EXECUTE vsql;
EXCEPTION WHEN invalid_table_definition THEN
  -- Column list changed; need CASCADE. Preserve dependent views first.
  SELECT c.oid INTO v_target_oid
  FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid
  WHERE n.nspname = v_target_schema AND c.relname = v_target_name AND c.relkind = 'v';
  IF v_target_oid IS NOT NULL THEN
    FOR v_dep IN
      WITH RECURSIVE deps AS (
        SELECT c.oid, c.relname AS name, n.nspname AS schema, 1 AS depth
        FROM pg_rewrite r
        JOIN pg_depend d ON d.objid = r.oid
        JOIN pg_class c ON c.oid = r.ev_class
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE d.refobjid = v_target_oid AND d.deptype = 'n'
          AND c.oid <> v_target_oid AND c.relkind = 'v'
        UNION
        SELECT c.oid, c.relname, n.nspname, p.depth + 1
        FROM deps p
        JOIN pg_rewrite r ON TRUE
        JOIN pg_depend d ON d.objid = r.oid AND d.refobjid = p.oid
        JOIN pg_class c ON c.oid = r.ev_class
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE c.relkind = 'v' AND c.oid <> p.oid
      )
      SELECT oid, name, schema, MAX(depth) AS max_depth,
             pg_catalog.pg_get_viewdef(oid, true) AS viewdef
      FROM deps GROUP BY oid, name, schema
      ORDER BY MAX(depth) ASC
    LOOP
      v_captured := v_captured || jsonb_build_object(
        'schema', v_dep.schema, 'name', v_dep.name, 'def', v_dep.viewdef);
    END LOOP;
  END IF;
  EXECUTE format('DROP VIEW IF EXISTS %I.%I CASCADE', v_target_schema, v_target_name);
  EXECUTE vsql;
  IF v_captured IS NOT NULL AND array_length(v_captured, 1) > 0 THEN
    FOR v_n IN 1..array_length(v_captured, 1) LOOP
      BEGIN
        EXECUTE format('CREATE VIEW %I.%I AS %s',
          v_captured[v_n]->>'schema', v_captured[v_n]->>'name', v_captured[v_n]->>'def');
      EXCEPTION WHEN others THEN
        RAISE WARNING 'Could not restore dependent view %.%: %',
          v_captured[v_n]->>'schema', v_captured[v_n]->>'name', SQLERRM;
      END;
    END LOOP;
  END IF;
END;
$do$;

DROP VIEW IF EXISTS "__mj_BizAppsIssues"."vwIssues" CASCADE;
DO $do$
DECLARE
  v_target_schema CONSTANT TEXT := '__mj_BizAppsIssues';
  v_target_name CONSTANT TEXT := 'vwIssues';
  vsql CONSTANT TEXT := $vsql$CREATE OR REPLACE VIEW "__mj_BizAppsIssues"."vwIssues"
AS SELECT
    i.*,
    "mjBizAppsIssuesIssueType_IssueTypeID"."Name" AS "IssueType",
    "mjBizAppsIssuesIssueStatus_StatusID"."Name" AS "Status",
    "mjBizAppsCommonPerson_ReporterPersonID"."DisplayName" AS "ReporterPerson",
    "MJEntity_AssigneeEntityID"."Name" AS "AssigneeEntity",
    "MJEntity_SourceEntityID"."Name" AS "SourceEntity",
    "mjBizAppsCommonPerson_CreatedByPersonID"."DisplayName" AS "CreatedByPerson"
FROM
    "__mj_BizAppsIssues"."Issue" AS i
INNER JOIN
    "__mj_BizAppsIssues"."IssueType" AS "mjBizAppsIssuesIssueType_IssueTypeID"
  ON
    i."IssueTypeID" = "mjBizAppsIssuesIssueType_IssueTypeID"."ID"
INNER JOIN
    "__mj_BizAppsIssues"."IssueStatus" AS "mjBizAppsIssuesIssueStatus_StatusID"
  ON
    i."StatusID" = "mjBizAppsIssuesIssueStatus_StatusID"."ID"
LEFT OUTER JOIN
    "${mjSchema}_BizAppsCommon"."Person" AS "mjBizAppsCommonPerson_ReporterPersonID"
  ON
    i."ReporterPersonID" = "mjBizAppsCommonPerson_ReporterPersonID"."ID"
LEFT OUTER JOIN
    "${mjSchema}"."Entity" AS "MJEntity_AssigneeEntityID"
  ON
    i."AssigneeEntityID" = "MJEntity_AssigneeEntityID"."ID"
LEFT OUTER JOIN
    "${mjSchema}"."Entity" AS "MJEntity_SourceEntityID"
  ON
    i."SourceEntityID" = "MJEntity_SourceEntityID"."ID"
LEFT OUTER JOIN
    "${mjSchema}_BizAppsCommon"."Person" AS "mjBizAppsCommonPerson_CreatedByPersonID"
  ON
    i."CreatedByPersonID" = "mjBizAppsCommonPerson_CreatedByPersonID"."ID"$vsql$;
  v_target_oid OID;
  v_dep RECORD;
  v_captured JSONB[] := ARRAY[]::JSONB[];
  v_n INTEGER;
BEGIN
  EXECUTE vsql;
EXCEPTION WHEN invalid_table_definition THEN
  -- Column list changed; need CASCADE. Preserve dependent views first.
  SELECT c.oid INTO v_target_oid
  FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid
  WHERE n.nspname = v_target_schema AND c.relname = v_target_name AND c.relkind = 'v';
  IF v_target_oid IS NOT NULL THEN
    FOR v_dep IN
      WITH RECURSIVE deps AS (
        SELECT c.oid, c.relname AS name, n.nspname AS schema, 1 AS depth
        FROM pg_rewrite r
        JOIN pg_depend d ON d.objid = r.oid
        JOIN pg_class c ON c.oid = r.ev_class
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE d.refobjid = v_target_oid AND d.deptype = 'n'
          AND c.oid <> v_target_oid AND c.relkind = 'v'
        UNION
        SELECT c.oid, c.relname, n.nspname, p.depth + 1
        FROM deps p
        JOIN pg_rewrite r ON TRUE
        JOIN pg_depend d ON d.objid = r.oid AND d.refobjid = p.oid
        JOIN pg_class c ON c.oid = r.ev_class
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE c.relkind = 'v' AND c.oid <> p.oid
      )
      SELECT oid, name, schema, MAX(depth) AS max_depth,
             pg_catalog.pg_get_viewdef(oid, true) AS viewdef
      FROM deps GROUP BY oid, name, schema
      ORDER BY MAX(depth) ASC
    LOOP
      v_captured := v_captured || jsonb_build_object(
        'schema', v_dep.schema, 'name', v_dep.name, 'def', v_dep.viewdef);
    END LOOP;
  END IF;
  EXECUTE format('DROP VIEW IF EXISTS %I.%I CASCADE', v_target_schema, v_target_name);
  EXECUTE vsql;
  IF v_captured IS NOT NULL AND array_length(v_captured, 1) > 0 THEN
    FOR v_n IN 1..array_length(v_captured, 1) LOOP
      BEGIN
        EXECUTE format('CREATE VIEW %I.%I AS %s',
          v_captured[v_n]->>'schema', v_captured[v_n]->>'name', v_captured[v_n]->>'def');
      EXCEPTION WHEN others THEN
        RAISE WARNING 'Could not restore dependent view %.%: %',
          v_captured[v_n]->>'schema', v_captured[v_n]->>'name', SQLERRM;
      END;
    END LOOP;
  END IF;
END;
$do$;


-- ===================== Stored Procedures (sp*) =====================

-- SKIPPED: procedure (auto-conversion not supported)
-- CREATE PROCEDURE [__mj_BizAppsIssues].[spCreateIssueNumberSequence]
--     @ScopeCode VARCHAR(50) = NULL,
--     @NextSequenceNumber INTEGER = NULL
-- AS
-- BEGIN
--     SET NOCOUNT ON;
--     
--     INSERT INTO
--     [__mj_B...

-- SKIPPED: procedure (auto-conversion not supported)
-- CREATE PROCEDURE [__mj_BizAppsIssues].[spUpdateIssueNumberSequence]
--     @ScopeCode VARCHAR(50),
--     @NextSequenceNumber INTEGER = NULL
-- AS
-- BEGIN
--     SET NOCOUNT ON;
--     UPDATE
--         [__mj_BizAppsIssues]...

-- SKIPPED: procedure (auto-conversion not supported)
-- CREATE PROCEDURE [__mj_BizAppsIssues].[spCreateIssueStatus]
--     @ID UUID = NULL,
--     @Name VARCHAR(100),
--     @Description_Clear bit = 0,
--     @Description TEXT = NULL,
--     @Sequen...

-- SKIPPED: procedure (auto-conversion not supported)
-- CREATE PROCEDURE [__mj_BizAppsIssues].[spUpdateIssueStatus]
--     @ID UUID,
--     @Name VARCHAR(100) = NULL,
--     @Description_Clear bit = 0,
--     @Description TEXT = NULL,
--     @Sequen...

-- SKIPPED: procedure (auto-conversion not supported)
-- CREATE PROCEDURE [__mj_BizAppsIssues].[spDeleteIssueNumberSequence]
--     @ScopeCode VARCHAR(50)
-- AS
-- BEGIN
--     SET NOCOUNT ON;
-- 
--     DELETE FROM
--         [__mj_BizAppsIssues].[IssueNumberSequence]
--     WHE...

-- SKIPPED: procedure (auto-conversion not supported)
-- CREATE PROCEDURE [__mj_BizAppsIssues].[spDeleteIssueStatus]
--     @ID UUID
-- AS
-- BEGIN
--     SET NOCOUNT ON;
-- 
--     DELETE FROM
--         [__mj_BizAppsIssues].[IssueStatus]
--     WHERE
--         [ID] = @...

-- SKIPPED: procedure (auto-conversion not supported)
-- CREATE PROCEDURE [__mj_BizAppsIssues].[spCreateIssueComment]
--     @ID UUID = NULL,
--     @IssueID UUID,
--     @Body TEXT,
--     @AuthorPersonID_Clear bit = 0,
--     @AuthorPers...

-- SKIPPED: procedure (auto-conversion not supported)
-- CREATE PROCEDURE [__mj_BizAppsIssues].[spUpdateIssueComment]
--     @ID UUID,
--     @IssueID UUID = NULL,
--     @Body TEXT = NULL,
--     @AuthorPersonID_Clear bit = 0,
--     @Aut...

-- SKIPPED: procedure (auto-conversion not supported)
-- CREATE PROCEDURE [__mj_BizAppsIssues].[spDeleteIssueComment]
--     @ID UUID
-- AS
-- BEGIN
--     SET NOCOUNT ON;
-- 
--     DELETE FROM
--         [__mj_BizAppsIssues].[IssueComment]
--     WHERE
--         [ID] =...

-- SKIPPED: procedure (auto-conversion not supported)
-- CREATE PROCEDURE [__mj_BizAppsIssues].[spCreateIssueType]
--     @ID UUID = NULL,
--     @Name VARCHAR(100),
--     @Description_Clear bit = 0,
--     @Description TEXT = NULL,
--     @IconClas...

-- SKIPPED: procedure (auto-conversion not supported)
-- CREATE PROCEDURE [__mj_BizAppsIssues].[spUpdateIssueType]
--     @ID UUID,
--     @Name VARCHAR(100) = NULL,
--     @Description_Clear bit = 0,
--     @Description TEXT = NULL,
--     @IconClas...

-- SKIPPED: procedure (auto-conversion not supported)
-- CREATE PROCEDURE [__mj_BizAppsIssues].[spDeleteIssueType]
--     @ID UUID
-- AS
-- BEGIN
--     SET NOCOUNT ON;
-- 
--     DELETE FROM
--         [__mj_BizAppsIssues].[IssueType]
--     WHERE
--         [ID] = @ID
-- 
-- ...

-- SKIPPED: procedure (auto-conversion not supported)
-- CREATE PROCEDURE [__mj_BizAppsIssues].[spCreateIssue]
--     @ID UUID = NULL,
--     @IssueNumber_Clear bit = 0,
--     @IssueNumber VARCHAR(50) = NULL,
--     @Title VARCHAR(500),
--     @Description_...

-- SKIPPED: procedure (auto-conversion not supported)
-- CREATE PROCEDURE [__mj_BizAppsIssues].[spUpdateIssue]
--     @ID UUID,
--     @IssueNumber_Clear bit = 0,
--     @IssueNumber VARCHAR(50) = NULL,
--     @Title VARCHAR(500) = NULL,
--     @Description_...

-- SKIPPED: procedure (auto-conversion not supported)
-- CREATE PROCEDURE [__mj_BizAppsIssues].[spDeleteIssue]
--     @ID UUID
-- AS
-- BEGIN
--     SET NOCOUNT ON;
-- 
--     DELETE FROM
--         [__mj_BizAppsIssues].[Issue]
--     WHERE
--         [ID] = @ID
-- 
-- 
--     -- ...


-- ===================== Triggers =====================

-- SKIPPED: trigger (auto-conversion not supported)
-- CREATE TRIGGER [__mj_BizAppsIssues].trgUpdateIssueNumberSequence
-- ON [__mj_BizAppsIssues].[IssueNumberSequence]
-- AFTER UPDATE
-- AS
-- BEGIN
--     SET NOCOUNT ON;
--     UPDATE
--         [__mj_BizAppsIssues].[IssueN

-- SKIPPED: trigger (auto-conversion not supported)
-- CREATE TRIGGER [__mj_BizAppsIssues].trgUpdateIssueStatus
-- ON [__mj_BizAppsIssues].[IssueStatus]
-- AFTER UPDATE
-- AS
-- BEGIN
--     SET NOCOUNT ON;
--     UPDATE
--         [__mj_BizAppsIssues].[IssueStatus]
--     SET
 

-- SKIPPED: trigger (auto-conversion not supported)
-- CREATE TRIGGER [__mj_BizAppsIssues].trgUpdateIssueComment
-- ON [__mj_BizAppsIssues].[IssueComment]
-- AFTER UPDATE
-- AS
-- BEGIN
--     SET NOCOUNT ON;
--     UPDATE
--         [__mj_BizAppsIssues].[IssueComment]
--     SE

-- SKIPPED: trigger (auto-conversion not supported)
-- CREATE TRIGGER [__mj_BizAppsIssues].trgUpdateIssueType
-- ON [__mj_BizAppsIssues].[IssueType]
-- AFTER UPDATE
-- AS
-- BEGIN
--     SET NOCOUNT ON;
--     UPDATE
--         [__mj_BizAppsIssues].[IssueType]
--     SET
       

-- SKIPPED: trigger (auto-conversion not supported)
-- CREATE TRIGGER [__mj_BizAppsIssues].trgUpdateIssue
-- ON [__mj_BizAppsIssues].[Issue]
-- AFTER UPDATE
-- AS
-- BEGIN
--     SET NOCOUNT ON;
--     UPDATE
--         [__mj_BizAppsIssues].[Issue]
--     SET
--         __mj_Update


-- ===================== Data (INSERT/UPDATE/DELETE) =====================

INSERT INTO "${mjSchema}"."Entity" (
         "ID",
         "Name",
         "DisplayName",
         "Description",
         "NameSuffix",
         "BaseTable",
         "BaseView",
         "SchemaName",
         "IncludeInAPI",
         "AllowUserSearchAPI",
         "AllowCaching"
         , "TrackRecordChanges"
         , "AuditRecordAccess"
         , "AuditViewRuns"
         , "AllowAllRowsAPI"
         , "AllowCreateAPI"
         , "AllowUpdateAPI"
         , "AllowDeleteAPI"
         , "UserViewMaxRows"
         , "__mj_CreatedAt"
         , "__mj_UpdatedAt"
      )
      VALUES (
         'b08fb976-cc72-4dac-b950-a5c86dd04267',
         'MJ_BizApps_Issues: Issue Types',
         'Issue Types',
         'Lifecycle automation for a class of issue (Bug, Feature Request, Question, Feedback). Mirrors the bizapps-tasks TaskType action-hook pattern: On*ActionID columns point at core "Action" records fired at the matching lifecycle event.',
         NULL,
         'IssueType',
         'vwIssueTypes',
         '__mj_BizAppsIssues',
         TRUE,
         TRUE,
         FALSE
         , TRUE
         , FALSE
         , FALSE
         , FALSE
         , TRUE
         , TRUE
         , TRUE
         , 1000
         , NOW()
         , NOW()
      );

/* SQL generated to create new application __mj_BizAppsIssues */

INSERT INTO "${mjSchema}"."Application" ("ID", "Name", "Description", "SchemaAutoAddNewEntities", "Path", "AutoUpdatePath")
                       VALUES ('7cc8c510-249d-4a54-a96d-198be952ef11', '__mj_BizAppsIssues', 'Generated for schema', '__mj_BizAppsIssues', 'mjbizappsissues', TRUE);

/* Adding role UI to application __mj_BizAppsIssues */

INSERT INTO "${mjSchema}"."ApplicationRole"
                                 ("ApplicationID", "RoleID", "CanAccess", "CanAdmin") VALUES
                                 ('7cc8c510-249d-4a54-a96d-198be952ef11', 'E0AFCCEC-6A37-EF11-86D4-000D3A4E707E', TRUE, FALSE);

/* Adding role Developer to application __mj_BizAppsIssues */

INSERT INTO "${mjSchema}"."ApplicationRole"
                                 ("ApplicationID", "RoleID", "CanAccess", "CanAdmin") VALUES
                                 ('7cc8c510-249d-4a54-a96d-198be952ef11', 'DEAFCCEC-6A37-EF11-86D4-000D3A4E707E', TRUE, TRUE);

/* Adding role Integration to application __mj_BizAppsIssues */

INSERT INTO "${mjSchema}"."ApplicationRole"
                                 ("ApplicationID", "RoleID", "CanAccess", "CanAdmin") VALUES
                                 ('7cc8c510-249d-4a54-a96d-198be952ef11', 'DFAFCCEC-6A37-EF11-86D4-000D3A4E707E', TRUE, FALSE);

/* SQL generated to add new entity MJ_BizApps_Issues: Issue Types to application ID: '7cc8c510-249d-4a54-a96d-198be952ef11' */

INSERT INTO "${mjSchema}"."ApplicationEntity"
                                       ("ApplicationID", "EntityID", "Sequence", "__mj_CreatedAt", "__mj_UpdatedAt") VALUES
                                       ('7cc8c510-249d-4a54-a96d-198be952ef11', 'b08fb976-cc72-4dac-b950-a5c86dd04267', (SELECT COALESCE(MAX("Sequence"),0)+1 FROM "${mjSchema}"."ApplicationEntity" WHERE "ApplicationID" = '7cc8c510-249d-4a54-a96d-198be952ef11'), NOW(), NOW());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Types for role UI */

INSERT INTO "${mjSchema}"."EntityPermission"
                                                   ("EntityID", "RoleID", "CanRead", "CanCreate", "CanUpdate", "CanDelete", "__mj_CreatedAt", "__mj_UpdatedAt") VALUES
                                                   ('b08fb976-cc72-4dac-b950-a5c86dd04267', 'E0AFCCEC-6A37-EF11-86D4-000D3A4E707E', TRUE, FALSE, FALSE, FALSE, NOW(), NOW());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Types for role Developer */

INSERT INTO "${mjSchema}"."EntityPermission"
                                                   ("EntityID", "RoleID", "CanRead", "CanCreate", "CanUpdate", "CanDelete", "__mj_CreatedAt", "__mj_UpdatedAt") VALUES
                                                   ('b08fb976-cc72-4dac-b950-a5c86dd04267', 'DEAFCCEC-6A37-EF11-86D4-000D3A4E707E', TRUE, TRUE, TRUE, TRUE, NOW(), NOW());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Types for role Integration */

INSERT INTO "${mjSchema}"."EntityPermission"
                                                   ("EntityID", "RoleID", "CanRead", "CanCreate", "CanUpdate", "CanDelete", "__mj_CreatedAt", "__mj_UpdatedAt") VALUES
                                                   ('b08fb976-cc72-4dac-b950-a5c86dd04267', 'DFAFCCEC-6A37-EF11-86D4-000D3A4E707E', TRUE, TRUE, TRUE, TRUE, NOW(), NOW());

/* SQL generated to create new entity MJ_BizApps_Issues: Issue Status */

INSERT INTO "${mjSchema}"."Entity" (
         "ID",
         "Name",
         "DisplayName",
         "Description",
         "NameSuffix",
         "BaseTable",
         "BaseView",
         "SchemaName",
         "IncludeInAPI",
         "AllowUserSearchAPI",
         "AllowCaching"
         , "TrackRecordChanges"
         , "AuditRecordAccess"
         , "AuditViewRuns"
         , "AllowAllRowsAPI"
         , "AllowCreateAPI"
         , "AllowUpdateAPI"
         , "AllowDeleteAPI"
         , "UserViewMaxRows"
         , "__mj_CreatedAt"
         , "__mj_UpdatedAt"
      )
      VALUES (
         '07e2bd79-ba8a-4b9c-8d45-4ea3a9922de4',
         'MJ_BizApps_Issues: Issue Status',
         'Issue Status',
         'Workflow state an Issue can be in (New, Triaged, In Progress, Resolved, Closed, ...). Seeded via metadata sync, not in this migration. Drives board columns.',
         NULL,
         'IssueStatus',
         'vwIssueStatus',
         '__mj_BizAppsIssues',
         TRUE,
         TRUE,
         FALSE
         , TRUE
         , FALSE
         , FALSE
         , FALSE
         , TRUE
         , TRUE
         , TRUE
         , 1000
         , NOW()
         , NOW()
      );

/* SQL generated to add new entity MJ_BizApps_Issues: Issue Status to application ID: '7CC8C510-249D-4A54-A96D-198BE952EF11' */

INSERT INTO "${mjSchema}"."ApplicationEntity"
                                       ("ApplicationID", "EntityID", "Sequence", "__mj_CreatedAt", "__mj_UpdatedAt") VALUES
                                       ('7CC8C510-249D-4A54-A96D-198BE952EF11', '07e2bd79-ba8a-4b9c-8d45-4ea3a9922de4', (SELECT COALESCE(MAX("Sequence"),0)+1 FROM "${mjSchema}"."ApplicationEntity" WHERE "ApplicationID" = '7CC8C510-249D-4A54-A96D-198BE952EF11'), NOW(), NOW());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Status for role UI */

INSERT INTO "${mjSchema}"."EntityPermission"
                                                   ("EntityID", "RoleID", "CanRead", "CanCreate", "CanUpdate", "CanDelete", "__mj_CreatedAt", "__mj_UpdatedAt") VALUES
                                                   ('07e2bd79-ba8a-4b9c-8d45-4ea3a9922de4', 'E0AFCCEC-6A37-EF11-86D4-000D3A4E707E', TRUE, FALSE, FALSE, FALSE, NOW(), NOW());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Status for role Developer */

INSERT INTO "${mjSchema}"."EntityPermission"
                                                   ("EntityID", "RoleID", "CanRead", "CanCreate", "CanUpdate", "CanDelete", "__mj_CreatedAt", "__mj_UpdatedAt") VALUES
                                                   ('07e2bd79-ba8a-4b9c-8d45-4ea3a9922de4', 'DEAFCCEC-6A37-EF11-86D4-000D3A4E707E', TRUE, TRUE, TRUE, TRUE, NOW(), NOW());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Status for role Integration */

INSERT INTO "${mjSchema}"."EntityPermission"
                                                   ("EntityID", "RoleID", "CanRead", "CanCreate", "CanUpdate", "CanDelete", "__mj_CreatedAt", "__mj_UpdatedAt") VALUES
                                                   ('07e2bd79-ba8a-4b9c-8d45-4ea3a9922de4', 'DFAFCCEC-6A37-EF11-86D4-000D3A4E707E', TRUE, TRUE, TRUE, TRUE, NOW(), NOW());

/* SQL generated to create new entity MJ_BizApps_Issues: Issues */

INSERT INTO "${mjSchema}"."Entity" (
         "ID",
         "Name",
         "DisplayName",
         "Description",
         "NameSuffix",
         "BaseTable",
         "BaseView",
         "SchemaName",
         "IncludeInAPI",
         "AllowUserSearchAPI",
         "AllowCaching"
         , "TrackRecordChanges"
         , "AuditRecordAccess"
         , "AuditViewRuns"
         , "AllowAllRowsAPI"
         , "AllowCreateAPI"
         , "AllowUpdateAPI"
         , "AllowDeleteAPI"
         , "UserViewMaxRows"
         , "__mj_CreatedAt"
         , "__mj_UpdatedAt"
      )
      VALUES (
         '65e7dad5-9930-4140-9a38-2184eb0097da',
         'MJ_BizApps_Issues: Issues',
         'Issues',
         'The core case / ticket / feedback record. Carries reporter, polymorphic assignee (Person or AI Agent), and a polymorphic source (any record the issue is about). Spawns bizapps-tasks Tasks for the actual work via TaskLink.',
         NULL,
         'Issue',
         'vwIssues',
         '__mj_BizAppsIssues',
         TRUE,
         TRUE,
         FALSE
         , TRUE
         , FALSE
         , FALSE
         , FALSE
         , TRUE
         , TRUE
         , TRUE
         , 1000
         , NOW()
         , NOW()
      );

/* SQL generated to add new entity MJ_BizApps_Issues: Issues to application ID: '7CC8C510-249D-4A54-A96D-198BE952EF11' */

INSERT INTO "${mjSchema}"."ApplicationEntity"
                                       ("ApplicationID", "EntityID", "Sequence", "__mj_CreatedAt", "__mj_UpdatedAt") VALUES
                                       ('7CC8C510-249D-4A54-A96D-198BE952EF11', '65e7dad5-9930-4140-9a38-2184eb0097da', (SELECT COALESCE(MAX("Sequence"),0)+1 FROM "${mjSchema}"."ApplicationEntity" WHERE "ApplicationID" = '7CC8C510-249D-4A54-A96D-198BE952EF11'), NOW(), NOW());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issues for role UI */

INSERT INTO "${mjSchema}"."EntityPermission"
                                                   ("EntityID", "RoleID", "CanRead", "CanCreate", "CanUpdate", "CanDelete", "__mj_CreatedAt", "__mj_UpdatedAt") VALUES
                                                   ('65e7dad5-9930-4140-9a38-2184eb0097da', 'E0AFCCEC-6A37-EF11-86D4-000D3A4E707E', TRUE, FALSE, FALSE, FALSE, NOW(), NOW());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issues for role Developer */

INSERT INTO "${mjSchema}"."EntityPermission"
                                                   ("EntityID", "RoleID", "CanRead", "CanCreate", "CanUpdate", "CanDelete", "__mj_CreatedAt", "__mj_UpdatedAt") VALUES
                                                   ('65e7dad5-9930-4140-9a38-2184eb0097da', 'DEAFCCEC-6A37-EF11-86D4-000D3A4E707E', TRUE, TRUE, TRUE, TRUE, NOW(), NOW());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issues for role Integration */

INSERT INTO "${mjSchema}"."EntityPermission"
                                                   ("EntityID", "RoleID", "CanRead", "CanCreate", "CanUpdate", "CanDelete", "__mj_CreatedAt", "__mj_UpdatedAt") VALUES
                                                   ('65e7dad5-9930-4140-9a38-2184eb0097da', 'DFAFCCEC-6A37-EF11-86D4-000D3A4E707E', TRUE, TRUE, TRUE, TRUE, NOW(), NOW());

/* SQL generated to create new entity MJ_BizApps_Issues: Issue Comments */

INSERT INTO "${mjSchema}"."Entity" (
         "ID",
         "Name",
         "DisplayName",
         "Description",
         "NameSuffix",
         "BaseTable",
         "BaseView",
         "SchemaName",
         "IncludeInAPI",
         "AllowUserSearchAPI",
         "AllowCaching"
         , "TrackRecordChanges"
         , "AuditRecordAccess"
         , "AuditViewRuns"
         , "AllowAllRowsAPI"
         , "AllowCreateAPI"
         , "AllowUpdateAPI"
         , "AllowDeleteAPI"
         , "UserViewMaxRows"
         , "__mj_CreatedAt"
         , "__mj_UpdatedAt"
      )
      VALUES (
         '7124a46d-ea35-4c8b-bbbb-f19287ed0f9b',
         'MJ_BizApps_Issues: Issue Comments',
         'Issue Comments',
         'Threaded discussion entry on an Issue. Author is a Person when internal; AuthorEmail carries the address for email / external sources.',
         NULL,
         'IssueComment',
         'vwIssueComments',
         '__mj_BizAppsIssues',
         TRUE,
         TRUE,
         FALSE
         , TRUE
         , FALSE
         , FALSE
         , FALSE
         , TRUE
         , TRUE
         , TRUE
         , 1000
         , NOW()
         , NOW()
      );

/* SQL generated to add new entity MJ_BizApps_Issues: Issue Comments to application ID: '7CC8C510-249D-4A54-A96D-198BE952EF11' */

INSERT INTO "${mjSchema}"."ApplicationEntity"
                                       ("ApplicationID", "EntityID", "Sequence", "__mj_CreatedAt", "__mj_UpdatedAt") VALUES
                                       ('7CC8C510-249D-4A54-A96D-198BE952EF11', '7124a46d-ea35-4c8b-bbbb-f19287ed0f9b', (SELECT COALESCE(MAX("Sequence"),0)+1 FROM "${mjSchema}"."ApplicationEntity" WHERE "ApplicationID" = '7CC8C510-249D-4A54-A96D-198BE952EF11'), NOW(), NOW());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Comments for role UI */

INSERT INTO "${mjSchema}"."EntityPermission"
                                                   ("EntityID", "RoleID", "CanRead", "CanCreate", "CanUpdate", "CanDelete", "__mj_CreatedAt", "__mj_UpdatedAt") VALUES
                                                   ('7124a46d-ea35-4c8b-bbbb-f19287ed0f9b', 'E0AFCCEC-6A37-EF11-86D4-000D3A4E707E', TRUE, FALSE, FALSE, FALSE, NOW(), NOW());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Comments for role Developer */

INSERT INTO "${mjSchema}"."EntityPermission"
                                                   ("EntityID", "RoleID", "CanRead", "CanCreate", "CanUpdate", "CanDelete", "__mj_CreatedAt", "__mj_UpdatedAt") VALUES
                                                   ('7124a46d-ea35-4c8b-bbbb-f19287ed0f9b', 'DEAFCCEC-6A37-EF11-86D4-000D3A4E707E', TRUE, TRUE, TRUE, TRUE, NOW(), NOW());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Comments for role Integration */

INSERT INTO "${mjSchema}"."EntityPermission"
                                                   ("EntityID", "RoleID", "CanRead", "CanCreate", "CanUpdate", "CanDelete", "__mj_CreatedAt", "__mj_UpdatedAt") VALUES
                                                   ('7124a46d-ea35-4c8b-bbbb-f19287ed0f9b', 'DFAFCCEC-6A37-EF11-86D4-000D3A4E707E', TRUE, TRUE, TRUE, TRUE, NOW(), NOW());

/* SQL generated to create new entity MJ_BizApps_Issues: Issue Number Sequences */

INSERT INTO "${mjSchema}"."Entity" (
         "ID",
         "Name",
         "DisplayName",
         "Description",
         "NameSuffix",
         "BaseTable",
         "BaseView",
         "SchemaName",
         "IncludeInAPI",
         "AllowUserSearchAPI",
         "AllowCaching"
         , "TrackRecordChanges"
         , "AuditRecordAccess"
         , "AuditViewRuns"
         , "AllowAllRowsAPI"
         , "AllowCreateAPI"
         , "AllowUpdateAPI"
         , "AllowDeleteAPI"
         , "UserViewMaxRows"
         , "__mj_CreatedAt"
         , "__mj_UpdatedAt"
      )
      VALUES (
         '595e3981-ee66-4b41-8579-2255a0c7610c',
         'MJ_BizApps_Issues: Issue Number Sequences',
         'Issue Number Sequences',
         'Per-scope gap-free counter backing the human-readable Issue."IssueNumber". One row per normalized ScopeCode. Maintained ONLY by spAssignNextIssueNumber — never write directly.',
         NULL,
         'IssueNumberSequence',
         'vwIssueNumberSequences',
         '__mj_BizAppsIssues',
         TRUE,
         TRUE,
         FALSE
         , TRUE
         , FALSE
         , FALSE
         , FALSE
         , TRUE
         , TRUE
         , TRUE
         , 1000
         , NOW()
         , NOW()
      );

/* SQL generated to add new entity MJ_BizApps_Issues: Issue Number Sequences to application ID: '7CC8C510-249D-4A54-A96D-198BE952EF11' */

INSERT INTO "${mjSchema}"."ApplicationEntity"
                                       ("ApplicationID", "EntityID", "Sequence", "__mj_CreatedAt", "__mj_UpdatedAt") VALUES
                                       ('7CC8C510-249D-4A54-A96D-198BE952EF11', '595e3981-ee66-4b41-8579-2255a0c7610c', (SELECT COALESCE(MAX("Sequence"),0)+1 FROM "${mjSchema}"."ApplicationEntity" WHERE "ApplicationID" = '7CC8C510-249D-4A54-A96D-198BE952EF11'), NOW(), NOW());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Number Sequences for role UI */

INSERT INTO "${mjSchema}"."EntityPermission"
                                                   ("EntityID", "RoleID", "CanRead", "CanCreate", "CanUpdate", "CanDelete", "__mj_CreatedAt", "__mj_UpdatedAt") VALUES
                                                   ('595e3981-ee66-4b41-8579-2255a0c7610c', 'E0AFCCEC-6A37-EF11-86D4-000D3A4E707E', TRUE, FALSE, FALSE, FALSE, NOW(), NOW());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Number Sequences for role Developer */

INSERT INTO "${mjSchema}"."EntityPermission"
                                                   ("EntityID", "RoleID", "CanRead", "CanCreate", "CanUpdate", "CanDelete", "__mj_CreatedAt", "__mj_UpdatedAt") VALUES
                                                   ('595e3981-ee66-4b41-8579-2255a0c7610c', 'DEAFCCEC-6A37-EF11-86D4-000D3A4E707E', TRUE, TRUE, TRUE, TRUE, NOW(), NOW());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Number Sequences for role Integration */

INSERT INTO "${mjSchema}"."EntityPermission"
                                                   ("EntityID", "RoleID", "CanRead", "CanCreate", "CanUpdate", "CanDelete", "__mj_CreatedAt", "__mj_UpdatedAt") VALUES
                                                   ('595e3981-ee66-4b41-8579-2255a0c7610c', 'DFAFCCEC-6A37-EF11-86D4-000D3A4E707E', TRUE, TRUE, TRUE, TRUE, NOW(), NOW());

/* SQL text to update existing entities from schema */

/* SQL text to add special date field __mj_CreatedAt to entity "__mj_BizAppsIssues"."Issue" */
UPDATE "__mj_BizAppsIssues"."Issue" SET "__mj_CreatedAt" = NOW() WHERE "__mj_CreatedAt" IS NULL;

/* SQL text to add special date field __mj_CreatedAt to entity "__mj_BizAppsIssues"."Issue" */
ALTER TABLE "__mj_BizAppsIssues"."Issue" ALTER COLUMN "__mj_CreatedAt" SET NOT NULL;

ALTER TABLE "__mj_BizAppsIssues"."Issue"
  ALTER COLUMN "__mj_CreatedAt" SET DEFAULT NOW();

/* SQL text to add special date field __mj_UpdatedAt to entity "__mj_BizAppsIssues"."Issue" */
UPDATE "__mj_BizAppsIssues"."Issue" SET "__mj_UpdatedAt" = NOW() WHERE "__mj_UpdatedAt" IS NULL;

/* SQL text to add special date field __mj_UpdatedAt to entity "__mj_BizAppsIssues"."Issue" */
ALTER TABLE "__mj_BizAppsIssues"."Issue" ALTER COLUMN "__mj_UpdatedAt" SET NOT NULL;

ALTER TABLE "__mj_BizAppsIssues"."Issue"
  ALTER COLUMN "__mj_UpdatedAt" SET DEFAULT NOW();

/* SQL text to add special date field __mj_CreatedAt to entity "__mj_BizAppsIssues"."IssueNumberSequence" */
UPDATE "__mj_BizAppsIssues"."IssueNumberSequence" SET "__mj_CreatedAt" = NOW() WHERE "__mj_CreatedAt" IS NULL;

/* SQL text to add special date field __mj_CreatedAt to entity "__mj_BizAppsIssues"."IssueNumberSequence" */
ALTER TABLE "__mj_BizAppsIssues"."IssueNumberSequence" ALTER COLUMN "__mj_CreatedAt" SET NOT NULL;

ALTER TABLE "__mj_BizAppsIssues"."IssueNumberSequence"
  ALTER COLUMN "__mj_CreatedAt" SET DEFAULT NOW();

/* SQL text to add special date field __mj_UpdatedAt to entity "__mj_BizAppsIssues"."IssueNumberSequence" */
UPDATE "__mj_BizAppsIssues"."IssueNumberSequence" SET "__mj_UpdatedAt" = NOW() WHERE "__mj_UpdatedAt" IS NULL;

/* SQL text to add special date field __mj_UpdatedAt to entity "__mj_BizAppsIssues"."IssueNumberSequence" */
ALTER TABLE "__mj_BizAppsIssues"."IssueNumberSequence" ALTER COLUMN "__mj_UpdatedAt" SET NOT NULL;

ALTER TABLE "__mj_BizAppsIssues"."IssueNumberSequence"
  ALTER COLUMN "__mj_UpdatedAt" SET DEFAULT NOW();

/* SQL text to add special date field __mj_CreatedAt to entity "__mj_BizAppsIssues"."IssueStatus" */
UPDATE "__mj_BizAppsIssues"."IssueStatus" SET "__mj_CreatedAt" = NOW() WHERE "__mj_CreatedAt" IS NULL;

/* SQL text to add special date field __mj_CreatedAt to entity "__mj_BizAppsIssues"."IssueStatus" */
ALTER TABLE "__mj_BizAppsIssues"."IssueStatus" ALTER COLUMN "__mj_CreatedAt" SET NOT NULL;

ALTER TABLE "__mj_BizAppsIssues"."IssueStatus"
  ALTER COLUMN "__mj_CreatedAt" SET DEFAULT NOW();

/* SQL text to add special date field __mj_UpdatedAt to entity "__mj_BizAppsIssues"."IssueStatus" */
UPDATE "__mj_BizAppsIssues"."IssueStatus" SET "__mj_UpdatedAt" = NOW() WHERE "__mj_UpdatedAt" IS NULL;

/* SQL text to add special date field __mj_UpdatedAt to entity "__mj_BizAppsIssues"."IssueStatus" */
ALTER TABLE "__mj_BizAppsIssues"."IssueStatus" ALTER COLUMN "__mj_UpdatedAt" SET NOT NULL;

ALTER TABLE "__mj_BizAppsIssues"."IssueStatus"
  ALTER COLUMN "__mj_UpdatedAt" SET DEFAULT NOW();

/* SQL text to add special date field __mj_CreatedAt to entity "__mj_BizAppsIssues"."IssueType" */
UPDATE "__mj_BizAppsIssues"."IssueType" SET "__mj_CreatedAt" = NOW() WHERE "__mj_CreatedAt" IS NULL;

/* SQL text to add special date field __mj_CreatedAt to entity "__mj_BizAppsIssues"."IssueType" */
ALTER TABLE "__mj_BizAppsIssues"."IssueType" ALTER COLUMN "__mj_CreatedAt" SET NOT NULL;

ALTER TABLE "__mj_BizAppsIssues"."IssueType"
  ALTER COLUMN "__mj_CreatedAt" SET DEFAULT NOW();

/* SQL text to add special date field __mj_UpdatedAt to entity "__mj_BizAppsIssues"."IssueType" */
UPDATE "__mj_BizAppsIssues"."IssueType" SET "__mj_UpdatedAt" = NOW() WHERE "__mj_UpdatedAt" IS NULL;

/* SQL text to add special date field __mj_UpdatedAt to entity "__mj_BizAppsIssues"."IssueType" */
ALTER TABLE "__mj_BizAppsIssues"."IssueType" ALTER COLUMN "__mj_UpdatedAt" SET NOT NULL;

ALTER TABLE "__mj_BizAppsIssues"."IssueType"
  ALTER COLUMN "__mj_UpdatedAt" SET DEFAULT NOW();

/* SQL text to add special date field __mj_CreatedAt to entity "__mj_BizAppsIssues"."IssueComment" */
UPDATE "__mj_BizAppsIssues"."IssueComment" SET "__mj_CreatedAt" = NOW() WHERE "__mj_CreatedAt" IS NULL;

/* SQL text to add special date field __mj_CreatedAt to entity "__mj_BizAppsIssues"."IssueComment" */
ALTER TABLE "__mj_BizAppsIssues"."IssueComment" ALTER COLUMN "__mj_CreatedAt" SET NOT NULL;

ALTER TABLE "__mj_BizAppsIssues"."IssueComment"
  ALTER COLUMN "__mj_CreatedAt" SET DEFAULT NOW();

/* SQL text to add special date field __mj_UpdatedAt to entity "__mj_BizAppsIssues"."IssueComment" */
UPDATE "__mj_BizAppsIssues"."IssueComment" SET "__mj_UpdatedAt" = NOW() WHERE "__mj_UpdatedAt" IS NULL;

/* SQL text to add special date field __mj_UpdatedAt to entity "__mj_BizAppsIssues"."IssueComment" */
ALTER TABLE "__mj_BizAppsIssues"."IssueComment" ALTER COLUMN "__mj_UpdatedAt" SET NOT NULL;

ALTER TABLE "__mj_BizAppsIssues"."IssueComment"
  ALTER COLUMN "__mj_UpdatedAt" SET DEFAULT NOW();

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'd3cf7eac-3527-47dd-87dd-da8744cda808' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = 'ID')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'd3cf7eac-3527-47dd-87dd-da8744cda808',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100001,
        'ID',
        'ID',
        'Unique identifier (UUID).',
        'UUID',
        16,
        0,
        0,
        FALSE,
        'gen_random_uuid()',
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        TRUE,
        TRUE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'adddcc67-6c31-4e40-8c22-aaaf2e9eb165' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = 'IssueNumber')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'adddcc67-6c31-4e40-8c22-aaaf2e9eb165',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100002,
        'IssueNumber',
        'Issue Number',
        'Human-readable case identifier, format {SCOPE}-{seq} (e.g. ''MJC-42''), where SCOPE is the normalized (trim/UPPER) AppScope or ''ISS'' when none. Assigned once on insert by spAssignNextIssueNumber via IssueEntityServer; immutable thereafter. UNIQUE. Per-AppScope (globally sequential across orgs sharing a scope) — Izzy layers a separate per-org TKT-#### on top.',
        'TEXT',
        100,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        TRUE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'fbda77b7-3edb-4d32-a7d4-06fe401457be' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = 'Title')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'fbda77b7-3edb-4d32-a7d4-06fe401457be',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100003,
        'Title',
        'Title',
        'Short, one-line summary of the issue.',
        'TEXT',
        1000,
        0,
        0,
        FALSE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '1ce66015-9e1b-4e20-be02-922d1d91a619' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = 'Description')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '1ce66015-9e1b-4e20-be02-922d1d91a619',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100004,
        'Description',
        'Description',
        'Full description / body of the issue (Markdown or plain text).',
        'TEXT',
        -1,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'e4408976-8a26-42d6-9b2d-81216476ad9c' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = 'IssueTypeID')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'e4408976-8a26-42d6-9b2d-81216476ad9c',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100005,
        'IssueTypeID',
        'Issue Type ID',
        'The IssueType classifying this issue. Drives lifecycle action hooks and the default spawned task type.',
        'UUID',
        16,
        0,
        0,
        FALSE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        'B08FB976-CC72-4DAC-B950-A5C86DD04267',
        'ID',
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '2963d2bc-0473-47a0-be0a-0e1bd925928b' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = 'StatusID')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '2963d2bc-0473-47a0-be0a-0e1bd925928b',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100006,
        'StatusID',
        'Status ID',
        'Current workflow status of the issue.',
        'UUID',
        16,
        0,
        0,
        FALSE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4',
        'ID',
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '99c48bc4-c15e-440a-a577-ec5ba8f9e48b' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = 'Severity')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '99c48bc4-c15e-440a-a577-ec5ba8f9e48b',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100007,
        'Severity',
        'Severity',
        'Impact of the issue (how bad it is): Low, Medium, High, Critical. Distinct from Priority.',
        'TEXT',
        40,
        0,
        0,
        FALSE,
        'Medium',
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '7c48ec27-0691-4ce9-b990-f554caf50864' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = 'Priority')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '7c48ec27-0691-4ce9-b990-f554caf50864',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100008,
        'Priority',
        'Priority',
        'Scheduling priority (how soon to address it): Low, Medium, High, Critical. Distinct from Severity.',
        'TEXT',
        40,
        0,
        0,
        FALSE,
        'Medium',
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '06ed94d8-4607-4061-888e-788ffafca023' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = 'ReporterPersonID')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '06ed94d8-4607-4061-888e-788ffafca023',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100009,
        'ReporterPersonID',
        'Reporter Person ID',
        'The Person who raised the issue, when known internally. NULL for external/anonymous reporters (use ReporterEmail).',
        'UUID',
        16,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        '7A94ADA9-7880-4FAE-97D8-DB0E934C3F5F',
        'ID',
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '65c94b3c-a5bf-4d2d-bbff-289a0c041047' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = 'ReporterEmail')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '65c94b3c-a5bf-4d2d-bbff-289a0c041047',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100010,
        'ReporterEmail',
        'Reporter Email',
        'Email of the reporter, used when there is no linked Person (external feedback, email-in).',
        'TEXT',
        640,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '5d649c62-6589-43f0-affd-e3f9e3268cc8' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = 'AssigneeEntityID')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '5d649c62-6589-43f0-affd-e3f9e3268cc8',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100011,
        'AssigneeEntityID',
        'Assignee Entity ID',
        'Polymorphic assignee: the core Entity of the assignee (e.g. a Person entity or an AI Agent entity). Paired with AssigneeRecordID.',
        'UUID',
        16,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        'E0238F34-2837-EF11-86D4-6045BDEE16E6',
        'ID',
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '24653d3b-faed-4a91-bd7f-8c903b8ad018' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = 'AssigneeRecordID')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '24653d3b-faed-4a91-bd7f-8c903b8ad018',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100012,
        'AssigneeRecordID',
        'Assignee Record ID',
        'Polymorphic assignee: the primary key (as string) of the assignee record within AssigneeEntityID.',
        'TEXT',
        900,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '9d602c66-9fb5-4514-9ed6-7b530012ae3a' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = 'SourceEntityID')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '9d602c66-9fb5-4514-9ed6-7b530012ae3a',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100013,
        'SourceEntityID',
        'Source Entity ID',
        'Polymorphic source: the core Entity of the record this issue is about (what the feedback concerns). Paired with SourceRecordID.',
        'UUID',
        16,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        'E0238F34-2837-EF11-86D4-6045BDEE16E6',
        'ID',
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '5e4d5272-5f71-4e7f-99b0-f0d9de5c3641' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = 'SourceRecordID')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '5e4d5272-5f71-4e7f-99b0-f0d9de5c3641',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100014,
        'SourceRecordID',
        'Source Record ID',
        'Polymorphic source: the primary key (as string) of the source record within SourceEntityID.',
        'TEXT',
        900,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'bdc175d9-3f7b-4818-af86-801d821b9276' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = 'AppScope')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'bdc175d9-3f7b-4818-af86-801d821b9276',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100015,
        'AppScope',
        'App Scope',
        'Which app / product this issue belongs to (free-text scope tag, e.g. ''MJC'', ''Explorer'').',
        'TEXT',
        510,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'd50b709a-c90f-4771-abef-9a108002a341' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = 'ResolvedAt')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'd50b709a-c90f-4771-abef-9a108002a341',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100016,
        'ResolvedAt',
        'Resolved At',
        'Timestamp the issue was resolved (entered a resolved state). NULL while unresolved.',
        'TIMESTAMPTZ',
        10,
        34,
        7,
        TRUE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '9ab132e0-fb1a-410a-a736-ddfbb0388f7e' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = 'ClosedAt')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '9ab132e0-fb1a-410a-a736-ddfbb0388f7e',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100017,
        'ClosedAt',
        'Closed At',
        'Timestamp the issue was closed (entered a terminal state). NULL while open.',
        'TIMESTAMPTZ',
        10,
        34,
        7,
        TRUE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '2bdfb21a-baf7-482d-98c5-4dfd03ff45ee' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = 'CreatedByPersonID')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '2bdfb21a-baf7-482d-98c5-4dfd03ff45ee',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100018,
        'CreatedByPersonID',
        'Created By Person ID',
        'The Person who created the issue record in the system (may differ from the reporter).',
        'UUID',
        16,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        '7A94ADA9-7880-4FAE-97D8-DB0E934C3F5F',
        'ID',
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'd6995810-5f0a-4775-8e81-9bd304dca9e0' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = '__mj_CreatedAt')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'd6995810-5f0a-4775-8e81-9bd304dca9e0',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100019,
        '__mj_CreatedAt',
        'Created At',
        NULL,
        'TIMESTAMPTZ',
        10,
        34,
        7,
        FALSE,
        'NOW()',
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '77f34775-1c61-4921-ac99-045d0a20b9bf' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = '__mj_UpdatedAt')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '77f34775-1c61-4921-ac99-045d0a20b9bf',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100020,
        '__mj_UpdatedAt',
        'Updated At',
        NULL,
        'TIMESTAMPTZ',
        10,
        34,
        7,
        FALSE,
        'NOW()',
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '3737e78f-3cab-49cf-ab9e-635da764e876' OR ("EntityID" = '595E3981-EE66-4B41-8579-2255A0C7610C' AND "Name" = 'ScopeCode')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '3737e78f-3cab-49cf-ab9e-635da764e876',
        '595E3981-EE66-4B41-8579-2255A0C7610C', -- "Entity": "MJ_BizApps_Issues": "Issue" "Number" "Sequences"
        100001,
        'ScopeCode',
        'Scope Code',
        'The normalized (trim/UPPER) AppScope this counter is for, or ''ISS'' when an issue has no AppScope. Primary key.',
        'TEXT',
        100,
        0,
        0,
        FALSE,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        TRUE,
        TRUE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '219d0d34-f277-4222-b9a1-f5a9f155abca' OR ("EntityID" = '595E3981-EE66-4B41-8579-2255A0C7610C' AND "Name" = 'NextSequenceNumber')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '219d0d34-f277-4222-b9a1-f5a9f155abca',
        '595E3981-EE66-4B41-8579-2255A0C7610C', -- "Entity": "MJ_BizApps_Issues": "Issue" "Number" "Sequences"
        100002,
        'NextSequenceNumber',
        'Next Sequence Number',
        'The next sequence value to assign for this scope. Incremented atomically (UPDLOCK/HOLDLOCK) by spAssignNextIssueNumber.',
        'INTEGER',
        4,
        10,
        0,
        FALSE,
        '(1)',
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'ee76be39-ba96-4c56-849b-d92c27504b43' OR ("EntityID" = '595E3981-EE66-4B41-8579-2255A0C7610C' AND "Name" = '__mj_CreatedAt')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'ee76be39-ba96-4c56-849b-d92c27504b43',
        '595E3981-EE66-4B41-8579-2255A0C7610C', -- "Entity": "MJ_BizApps_Issues": "Issue" "Number" "Sequences"
        100003,
        '__mj_CreatedAt',
        'Created At',
        NULL,
        'TIMESTAMPTZ',
        10,
        34,
        7,
        FALSE,
        'NOW()',
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '30118bfc-fe8a-4fe4-903c-79184edce894' OR ("EntityID" = '595E3981-EE66-4B41-8579-2255A0C7610C' AND "Name" = '__mj_UpdatedAt')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '30118bfc-fe8a-4fe4-903c-79184edce894',
        '595E3981-EE66-4B41-8579-2255A0C7610C', -- "Entity": "MJ_BizApps_Issues": "Issue" "Number" "Sequences"
        100004,
        '__mj_UpdatedAt',
        'Updated At',
        NULL,
        'TIMESTAMPTZ',
        10,
        34,
        7,
        FALSE,
        'NOW()',
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '53331d4b-d295-4df9-a97b-9f63bce62e71' OR ("EntityID" = '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4' AND "Name" = 'ID')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '53331d4b-d295-4df9-a97b-9f63bce62e71',
        '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4', -- "Entity": "MJ_BizApps_Issues": "Issue" "Status"
        100001,
        'ID',
        'ID',
        'Unique identifier (UUID).',
        'UUID',
        16,
        0,
        0,
        FALSE,
        'gen_random_uuid()',
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        TRUE,
        TRUE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '71b2f634-7594-490a-9bfd-d130b8193c5e' OR ("EntityID" = '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4' AND "Name" = 'Name')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '71b2f634-7594-490a-9bfd-d130b8193c5e',
        '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4', -- "Entity": "MJ_BizApps_Issues": "Issue" "Status"
        100002,
        'Name',
        'Name',
        'Display name of the status (unique). E.g. ''In Progress'', ''Resolved''.',
        'TEXT',
        200,
        0,
        0,
        FALSE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        TRUE,
        TRUE,
        FALSE,
        TRUE,
        FALSE,
        TRUE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '9487b754-90b9-42f9-ae1c-b59b0becfb2c' OR ("EntityID" = '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4' AND "Name" = 'Description')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '9487b754-90b9-42f9-ae1c-b59b0becfb2c',
        '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4', -- "Entity": "MJ_BizApps_Issues": "Issue" "Status"
        100003,
        'Description',
        'Description',
        'Detailed description of what this status means in the workflow.',
        'TEXT',
        -1,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'da13598b-b481-48a7-969d-ac8cc80af61a' OR ("EntityID" = '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4' AND "Name" = 'Sequence')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'da13598b-b481-48a7-969d-ac8cc80af61a',
        '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4', -- "Entity": "MJ_BizApps_Issues": "Issue" "Status"
        100004,
        'Sequence',
        'Sequence',
        'Sort order of the status on boards and in dropdowns. Lower values appear first.',
        'INTEGER',
        4,
        10,
        0,
        FALSE,
        '(100)',
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'e66776d3-0318-4c92-b30a-373fb4d64d9d' OR ("EntityID" = '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4' AND "Name" = 'IsDefault')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'e66776d3-0318-4c92-b30a-373fb4d64d9d',
        '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4', -- "Entity": "MJ_BizApps_Issues": "Issue" "Status"
        100005,
        'IsDefault',
        'Is Default',
        'Whether new issues default to this status. Exactly one status should have this set.',
        'BOOLEAN',
        1,
        1,
        0,
        FALSE,
        '(0)',
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '04aa5244-2c13-4768-826b-94f72805efd5' OR ("EntityID" = '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4' AND "Name" = 'IsTerminal')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '04aa5244-2c13-4768-826b-94f72805efd5',
        '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4', -- "Entity": "MJ_BizApps_Issues": "Issue" "Status"
        100006,
        'IsTerminal',
        'Is Terminal',
        'Whether this is a terminal (end) state such as Closed or Won''t Fix. Terminal statuses stop SLA timers and remove the issue from active queues.',
        'BOOLEAN',
        1,
        1,
        0,
        FALSE,
        '(0)',
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '796866ab-7cae-4ce7-9e17-2b7a38e86639' OR ("EntityID" = '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4' AND "Name" = 'ColorCode')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '796866ab-7cae-4ce7-9e17-2b7a38e86639',
        '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4', -- "Entity": "MJ_BizApps_Issues": "Issue" "Status"
        100007,
        'ColorCode',
        'Color Code',
        'Hex (or token) color used to render this status as a chip / board column header.',
        'TEXT',
        40,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '29e0d51a-6e88-44f6-b2c5-6156bc4fafca' OR ("EntityID" = '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4' AND "Name" = '__mj_CreatedAt')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '29e0d51a-6e88-44f6-b2c5-6156bc4fafca',
        '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4', -- "Entity": "MJ_BizApps_Issues": "Issue" "Status"
        100008,
        '__mj_CreatedAt',
        'Created At',
        NULL,
        'TIMESTAMPTZ',
        10,
        34,
        7,
        FALSE,
        'NOW()',
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'a40692e4-de3e-41bf-acbd-d1cb45d4d1ab' OR ("EntityID" = '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4' AND "Name" = '__mj_UpdatedAt')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'a40692e4-de3e-41bf-acbd-d1cb45d4d1ab',
        '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4', -- "Entity": "MJ_BizApps_Issues": "Issue" "Status"
        100009,
        '__mj_UpdatedAt',
        'Updated At',
        NULL,
        'TIMESTAMPTZ',
        10,
        34,
        7,
        FALSE,
        'NOW()',
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'e6f9e9bb-4c8a-45b7-94db-452b255dc1a1' OR ("EntityID" = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND "Name" = 'ID')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'e6f9e9bb-4c8a-45b7-94db-452b255dc1a1',
        'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- "Entity": "MJ_BizApps_Issues": "Issue" "Types"
        100001,
        'ID',
        'ID',
        'Unique identifier (UUID).',
        'UUID',
        16,
        0,
        0,
        FALSE,
        'gen_random_uuid()',
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        TRUE,
        TRUE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '1b4a00a6-7843-49c4-93f3-d5c13272070b' OR ("EntityID" = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND "Name" = 'Name')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '1b4a00a6-7843-49c4-93f3-d5c13272070b',
        'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- "Entity": "MJ_BizApps_Issues": "Issue" "Types"
        100002,
        'Name',
        'Name',
        'Display name of the issue type (unique). E.g. ''Bug'', ''Feature Request''.',
        'TEXT',
        200,
        0,
        0,
        FALSE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        TRUE,
        TRUE,
        FALSE,
        TRUE,
        FALSE,
        TRUE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '0e58fdbe-c30e-41c9-abc2-51de6b1bd2d6' OR ("EntityID" = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND "Name" = 'Description')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '0e58fdbe-c30e-41c9-abc2-51de6b1bd2d6',
        'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- "Entity": "MJ_BizApps_Issues": "Issue" "Types"
        100003,
        'Description',
        'Description',
        'Detailed description of what this issue type represents and when to use it.',
        'TEXT',
        -1,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'f06f4ff7-111b-407b-99f0-0b551c656f43' OR ("EntityID" = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND "Name" = 'IconClass')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'f06f4ff7-111b-407b-99f0-0b551c656f43',
        'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- "Entity": "MJ_BizApps_Issues": "Issue" "Types"
        100004,
        'IconClass',
        'Icon Class',
        'Font Awesome (or similar) icon class shown next to issues of this type in the UI.',
        'TEXT',
        200,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'efb68536-dc99-4f27-a77a-bf23a026ea67' OR ("EntityID" = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND "Name" = 'DefaultPriority')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'efb68536-dc99-4f27-a77a-bf23a026ea67',
        'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- "Entity": "MJ_BizApps_Issues": "Issue" "Types"
        100005,
        'DefaultPriority',
        'Default Priority',
        'Priority assigned to new issues of this type when none is specified. One of Low, Medium, High, Critical.',
        'TEXT',
        40,
        0,
        0,
        FALSE,
        'Medium',
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '6c0b349f-4042-42b6-b8f9-b9d4a681de80' OR ("EntityID" = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND "Name" = 'DefaultTaskTypeID')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '6c0b349f-4042-42b6-b8f9-b9d4a681de80',
        'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- "Entity": "MJ_BizApps_Issues": "Issue" "Types"
        100006,
        'DefaultTaskTypeID',
        'Default Task Type ID',
        'bizapps-tasks TaskType used when an Issue of this type spawns work via IssueWorkService. NULL = let the caller choose.',
        'UUID',
        16,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        '1E30141A-826F-4278-BAA9-BBE14D29E606',
        'ID',
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '86b9ec44-d8da-4540-9638-db50f4d92bc4' OR ("EntityID" = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND "Name" = 'OnCreateActionID')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '86b9ec44-d8da-4540-9638-db50f4d92bc4',
        'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- "Entity": "MJ_BizApps_Issues": "Issue" "Types"
        100007,
        'OnCreateActionID',
        'On Create Action ID',
        'Action fired by IssueService when an Issue of this type is created.',
        'UUID',
        16,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        '38248F34-2837-EF11-86D4-6045BDEE16E6',
        'ID',
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '7d858a44-3534-468d-9e48-be4c8dc93052' OR ("EntityID" = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND "Name" = 'OnStatusChangeActionID')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '7d858a44-3534-468d-9e48-be4c8dc93052',
        'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- "Entity": "MJ_BizApps_Issues": "Issue" "Types"
        100008,
        'OnStatusChangeActionID',
        'On Status Change Action ID',
        'Action fired by IssueService when an Issue of this type changes status.',
        'UUID',
        16,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        '38248F34-2837-EF11-86D4-6045BDEE16E6',
        'ID',
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'ae7027e2-994b-45ec-9f35-220a7664ab85' OR ("EntityID" = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND "Name" = 'OnAssignActionID')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'ae7027e2-994b-45ec-9f35-220a7664ab85',
        'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- "Entity": "MJ_BizApps_Issues": "Issue" "Types"
        100009,
        'OnAssignActionID',
        'On Assign Action ID',
        'Action fired by IssueService when an Issue of this type is assigned.',
        'UUID',
        16,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        '38248F34-2837-EF11-86D4-6045BDEE16E6',
        'ID',
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '569d75f7-f081-4bc2-8990-321b8b9d92b6' OR ("EntityID" = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND "Name" = 'OnCloseActionID')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '569d75f7-f081-4bc2-8990-321b8b9d92b6',
        'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- "Entity": "MJ_BizApps_Issues": "Issue" "Types"
        100010,
        'OnCloseActionID',
        'On Close Action ID',
        'Action fired by IssueService when an Issue of this type is closed.',
        'UUID',
        16,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        '38248F34-2837-EF11-86D4-6045BDEE16E6',
        'ID',
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '4fea107e-b189-4bad-85a6-7ecfabbf9b15' OR ("EntityID" = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND "Name" = 'IsActive')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '4fea107e-b189-4bad-85a6-7ecfabbf9b15',
        'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- "Entity": "MJ_BizApps_Issues": "Issue" "Types"
        100011,
        'IsActive',
        'Is Active',
        'Whether this issue type is available for new issues. Inactive types stay on historical issues but are hidden from selection.',
        'BOOLEAN',
        1,
        1,
        0,
        FALSE,
        '(1)',
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'e8f4cc38-d394-442e-a438-e30e70f07a5d' OR ("EntityID" = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND "Name" = '__mj_CreatedAt')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'e8f4cc38-d394-442e-a438-e30e70f07a5d',
        'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- "Entity": "MJ_BizApps_Issues": "Issue" "Types"
        100012,
        '__mj_CreatedAt',
        'Created At',
        NULL,
        'TIMESTAMPTZ',
        10,
        34,
        7,
        FALSE,
        'NOW()',
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'f09b3838-633a-4b51-88ca-5ab6e5e0af5d' OR ("EntityID" = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND "Name" = '__mj_UpdatedAt')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'f09b3838-633a-4b51-88ca-5ab6e5e0af5d',
        'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- "Entity": "MJ_BizApps_Issues": "Issue" "Types"
        100013,
        '__mj_UpdatedAt',
        'Updated At',
        NULL,
        'TIMESTAMPTZ',
        10,
        34,
        7,
        FALSE,
        'NOW()',
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '56419321-e23c-44ae-92e5-60060382f4fa' OR ("EntityID" = '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B' AND "Name" = 'ID')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '56419321-e23c-44ae-92e5-60060382f4fa',
        '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B', -- "Entity": "MJ_BizApps_Issues": "Issue" "Comments"
        100001,
        'ID',
        'ID',
        'Unique identifier (UUID).',
        'UUID',
        16,
        0,
        0,
        FALSE,
        'gen_random_uuid()',
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        TRUE,
        TRUE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'bb65e98f-c7c3-41bc-a268-5added0d5f5f' OR ("EntityID" = '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B' AND "Name" = 'IssueID')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'bb65e98f-c7c3-41bc-a268-5added0d5f5f',
        '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B', -- "Entity": "MJ_BizApps_Issues": "Issue" "Comments"
        100002,
        'IssueID',
        'Issue ID',
        'The Issue this comment belongs to.',
        'UUID',
        16,
        0,
        0,
        FALSE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        '65E7DAD5-9930-4140-9A38-2184EB0097DA',
        'ID',
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '4fb78308-1867-468d-916a-8118960e8c55' OR ("EntityID" = '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B' AND "Name" = 'Body')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '4fb78308-1867-468d-916a-8118960e8c55',
        '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B', -- "Entity": "MJ_BizApps_Issues": "Issue" "Comments"
        100003,
        'Body',
        'Body',
        'Comment body (Markdown or plain text).',
        'TEXT',
        -1,
        0,
        0,
        FALSE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '31762b00-ece7-4760-ac10-b11d53793fbc' OR ("EntityID" = '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B' AND "Name" = 'AuthorPersonID')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '31762b00-ece7-4760-ac10-b11d53793fbc',
        '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B', -- "Entity": "MJ_BizApps_Issues": "Issue" "Comments"
        100004,
        'AuthorPersonID',
        'Author Person ID',
        'The Person who authored the comment, when internal. NULL for email/external authors (use AuthorEmail).',
        'UUID',
        16,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        '7A94ADA9-7880-4FAE-97D8-DB0E934C3F5F',
        'ID',
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '0b6ee56c-7364-491f-bc0b-de8b0d69d271' OR ("EntityID" = '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B' AND "Name" = 'AuthorEmail')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '0b6ee56c-7364-491f-bc0b-de8b0d69d271',
        '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B', -- "Entity": "MJ_BizApps_Issues": "Issue" "Comments"
        100005,
        'AuthorEmail',
        'Author Email',
        'Email of the comment author, used when there is no linked Person.',
        'TEXT',
        640,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '89d0ecae-49f6-4730-b9e4-1f0cfe373571' OR ("EntityID" = '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B' AND "Name" = 'Source')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '89d0ecae-49f6-4730-b9e4-1f0cfe373571',
        '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B', -- "Entity": "MJ_BizApps_Issues": "Issue" "Comments"
        100006,
        'Source',
        'Source',
        'Origin of the comment: ''internal'' (in-app), ''email'' (email reply), or ''external'' (reserved for v1.1 provider sync).',
        'TEXT',
        40,
        0,
        0,
        FALSE,
        'internal',
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'ef200acb-07a0-44be-9c7a-d14f4a72dcd2' OR ("EntityID" = '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B' AND "Name" = '__mj_CreatedAt')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'ef200acb-07a0-44be-9c7a-d14f4a72dcd2',
        '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B', -- "Entity": "MJ_BizApps_Issues": "Issue" "Comments"
        100007,
        '__mj_CreatedAt',
        'Created At',
        NULL,
        'TIMESTAMPTZ',
        10,
        34,
        7,
        FALSE,
        'NOW()',
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '84fda08a-9365-4e56-8129-9808d2de19cd' OR ("EntityID" = '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B' AND "Name" = '__mj_UpdatedAt')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '84fda08a-9365-4e56-8129-9808d2de19cd',
        '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B', -- "Entity": "MJ_BizApps_Issues": "Issue" "Comments"
        100008,
        '__mj_UpdatedAt',
        'Updated At',
        NULL,
        'TIMESTAMPTZ',
        10,
        34,
        7,
        FALSE,
        'NOW()',
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

INSERT INTO "${mjSchema}"."EntityFieldValue"
                                       ("ID", "EntityFieldID", "Sequence", "Value", "Code", "__mj_CreatedAt", "__mj_UpdatedAt")
                                    VALUES
                                       ('f4da53b8-1f68-4b47-9fed-9b1c6b994e2e', 'EFB68536-DC99-4F27-A77A-BF23A026EA67', 1, 'Critical', 'Critical', NOW(), NOW());

/* SQL text to insert entity field value with ID b270a0e0-c7be-4501-b286-86cc2e283687 */

INSERT INTO "${mjSchema}"."EntityFieldValue"
                                       ("ID", "EntityFieldID", "Sequence", "Value", "Code", "__mj_CreatedAt", "__mj_UpdatedAt")
                                    VALUES
                                       ('b270a0e0-c7be-4501-b286-86cc2e283687', 'EFB68536-DC99-4F27-A77A-BF23A026EA67', 2, 'High', 'High', NOW(), NOW());

/* SQL text to insert entity field value with ID 813067f5-4b0e-40a6-b520-a2a3aa625a5f */

INSERT INTO "${mjSchema}"."EntityFieldValue"
                                       ("ID", "EntityFieldID", "Sequence", "Value", "Code", "__mj_CreatedAt", "__mj_UpdatedAt")
                                    VALUES
                                       ('813067f5-4b0e-40a6-b520-a2a3aa625a5f', 'EFB68536-DC99-4F27-A77A-BF23A026EA67', 3, 'Low', 'Low', NOW(), NOW());

/* SQL text to insert entity field value with ID 65f40fc7-4e6a-47e0-b9b7-fb50af4ba974 */

INSERT INTO "${mjSchema}"."EntityFieldValue"
                                       ("ID", "EntityFieldID", "Sequence", "Value", "Code", "__mj_CreatedAt", "__mj_UpdatedAt")
                                    VALUES
                                       ('65f40fc7-4e6a-47e0-b9b7-fb50af4ba974', 'EFB68536-DC99-4F27-A77A-BF23A026EA67', 4, 'Medium', 'Medium', NOW(), NOW());

/* SQL text to update ValueListType for entity field ID EFB68536-DC99-4F27-A77A-BF23A026EA67 */

UPDATE "${mjSchema}"."EntityField" SET "ValueListType"='List' WHERE "ID"='EFB68536-DC99-4F27-A77A-BF23A026EA67';

/* SQL text to insert entity field value with ID ca6fc02c-b8cb-4d23-beea-e6723b62819c */

INSERT INTO "${mjSchema}"."EntityFieldValue"
                                       ("ID", "EntityFieldID", "Sequence", "Value", "Code", "__mj_CreatedAt", "__mj_UpdatedAt")
                                    VALUES
                                       ('ca6fc02c-b8cb-4d23-beea-e6723b62819c', '99C48BC4-C15E-440A-A577-EC5BA8F9E48B', 1, 'Critical', 'Critical', NOW(), NOW());

/* SQL text to insert entity field value with ID fab9481d-7b62-43a9-b877-de9e64384e9b */

INSERT INTO "${mjSchema}"."EntityFieldValue"
                                       ("ID", "EntityFieldID", "Sequence", "Value", "Code", "__mj_CreatedAt", "__mj_UpdatedAt")
                                    VALUES
                                       ('fab9481d-7b62-43a9-b877-de9e64384e9b', '99C48BC4-C15E-440A-A577-EC5BA8F9E48B', 2, 'High', 'High', NOW(), NOW());

/* SQL text to insert entity field value with ID 6df6d410-ec3b-4bb8-a516-7e1503239c95 */

INSERT INTO "${mjSchema}"."EntityFieldValue"
                                       ("ID", "EntityFieldID", "Sequence", "Value", "Code", "__mj_CreatedAt", "__mj_UpdatedAt")
                                    VALUES
                                       ('6df6d410-ec3b-4bb8-a516-7e1503239c95', '99C48BC4-C15E-440A-A577-EC5BA8F9E48B', 3, 'Low', 'Low', NOW(), NOW());

/* SQL text to insert entity field value with ID e2894566-56a3-447a-862d-991ef022c901 */

INSERT INTO "${mjSchema}"."EntityFieldValue"
                                       ("ID", "EntityFieldID", "Sequence", "Value", "Code", "__mj_CreatedAt", "__mj_UpdatedAt")
                                    VALUES
                                       ('e2894566-56a3-447a-862d-991ef022c901', '99C48BC4-C15E-440A-A577-EC5BA8F9E48B', 4, 'Medium', 'Medium', NOW(), NOW());

/* SQL text to update ValueListType for entity field ID 99C48BC4-C15E-440A-A577-EC5BA8F9E48B */

UPDATE "${mjSchema}"."EntityField" SET "ValueListType"='List' WHERE "ID"='99C48BC4-C15E-440A-A577-EC5BA8F9E48B';

/* SQL text to insert entity field value with ID 5528e199-3685-4c18-9111-5317317eef89 */

INSERT INTO "${mjSchema}"."EntityFieldValue"
                                       ("ID", "EntityFieldID", "Sequence", "Value", "Code", "__mj_CreatedAt", "__mj_UpdatedAt")
                                    VALUES
                                       ('5528e199-3685-4c18-9111-5317317eef89', '7C48EC27-0691-4CE9-B990-F554CAF50864', 1, 'Critical', 'Critical', NOW(), NOW());

/* SQL text to insert entity field value with ID 841e073d-a57c-4955-8564-c0ada179919b */

INSERT INTO "${mjSchema}"."EntityFieldValue"
                                       ("ID", "EntityFieldID", "Sequence", "Value", "Code", "__mj_CreatedAt", "__mj_UpdatedAt")
                                    VALUES
                                       ('841e073d-a57c-4955-8564-c0ada179919b', '7C48EC27-0691-4CE9-B990-F554CAF50864', 2, 'High', 'High', NOW(), NOW());

/* SQL text to insert entity field value with ID f597c29a-597c-401a-81dd-121b5d78fa3c */

INSERT INTO "${mjSchema}"."EntityFieldValue"
                                       ("ID", "EntityFieldID", "Sequence", "Value", "Code", "__mj_CreatedAt", "__mj_UpdatedAt")
                                    VALUES
                                       ('f597c29a-597c-401a-81dd-121b5d78fa3c', '7C48EC27-0691-4CE9-B990-F554CAF50864', 3, 'Low', 'Low', NOW(), NOW());

/* SQL text to insert entity field value with ID 736dc174-b083-4377-9095-536851653c53 */

INSERT INTO "${mjSchema}"."EntityFieldValue"
                                       ("ID", "EntityFieldID", "Sequence", "Value", "Code", "__mj_CreatedAt", "__mj_UpdatedAt")
                                    VALUES
                                       ('736dc174-b083-4377-9095-536851653c53', '7C48EC27-0691-4CE9-B990-F554CAF50864', 4, 'Medium', 'Medium', NOW(), NOW());

/* SQL text to update ValueListType for entity field ID 7C48EC27-0691-4CE9-B990-F554CAF50864 */

UPDATE "${mjSchema}"."EntityField" SET "ValueListType"='List' WHERE "ID"='7C48EC27-0691-4CE9-B990-F554CAF50864';

/* SQL text to insert entity field value with ID e875c064-3d9d-407e-a4e5-c27c1f793206 */

INSERT INTO "${mjSchema}"."EntityFieldValue"
                                       ("ID", "EntityFieldID", "Sequence", "Value", "Code", "__mj_CreatedAt", "__mj_UpdatedAt")
                                    VALUES
                                       ('e875c064-3d9d-407e-a4e5-c27c1f793206', '89D0ECAE-49F6-4730-B9E4-1F0CFE373571', 1, 'email', 'email', NOW(), NOW());

/* SQL text to insert entity field value with ID d954ba16-f348-4746-a7a7-5273c3ef3834 */

INSERT INTO "${mjSchema}"."EntityFieldValue"
                                       ("ID", "EntityFieldID", "Sequence", "Value", "Code", "__mj_CreatedAt", "__mj_UpdatedAt")
                                    VALUES
                                       ('d954ba16-f348-4746-a7a7-5273c3ef3834', '89D0ECAE-49F6-4730-B9E4-1F0CFE373571', 2, 'external', 'external', NOW(), NOW());

/* SQL text to insert entity field value with ID cb674c9d-5dc8-42b4-b37b-59cb1cc1a81c */

INSERT INTO "${mjSchema}"."EntityFieldValue"
                                       ("ID", "EntityFieldID", "Sequence", "Value", "Code", "__mj_CreatedAt", "__mj_UpdatedAt")
                                    VALUES
                                       ('cb674c9d-5dc8-42b4-b37b-59cb1cc1a81c', '89D0ECAE-49F6-4730-B9E4-1F0CFE373571', 3, 'internal', 'internal', NOW(), NOW());

/* SQL text to update ValueListType for entity field ID 89D0ECAE-49F6-4730-B9E4-1F0CFE373571 */

UPDATE "${mjSchema}"."EntityField" SET "ValueListType"='List' WHERE "ID"='89D0ECAE-49F6-4730-B9E4-1F0CFE373571';


/* Create Entity Relationship: MJ_BizApps_Issues: Issues -> MJ_BizApps_Issues: Issue Comments (One To Many via IssueID) */

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityRelationship" WHERE "ID" = 'cae6eb89-1cb9-4391-81d9-124bbac74644'
    ) THEN
        INSERT INTO "${mjSchema}"."EntityRelationship" ("ID", "EntityID", "RelatedEntityID", "RelatedEntityJoinField", "Type", "BundleInAPI", "DisplayInForm", "Sequence", "__mj_CreatedAt", "__mj_UpdatedAt")
        VALUES ('cae6eb89-1cb9-4391-81d9-124bbac74644', '65E7DAD5-9930-4140-9A38-2184EB0097DA', '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B', 'IssueID', 'One To Many', TRUE, TRUE, 1, NOW(), NOW());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityRelationship" WHERE "ID" = '74a84bb4-67d9-4e29-89a2-0818b142b9ec'
    ) THEN
        INSERT INTO "${mjSchema}"."EntityRelationship" ("ID", "EntityID", "RelatedEntityID", "RelatedEntityJoinField", "Type", "BundleInAPI", "DisplayInForm", "Sequence", "__mj_CreatedAt", "__mj_UpdatedAt")
        VALUES ('74a84bb4-67d9-4e29-89a2-0818b142b9ec', '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4', '65E7DAD5-9930-4140-9A38-2184EB0097DA', 'StatusID', 'One To Many', TRUE, TRUE, 1, NOW(), NOW());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityRelationship" WHERE "ID" = 'd3c32ecd-b2f2-4cc5-8878-b62e6d4b5945'
    ) THEN
        INSERT INTO "${mjSchema}"."EntityRelationship" ("ID", "EntityID", "RelatedEntityID", "RelatedEntityJoinField", "Type", "BundleInAPI", "DisplayInForm", "Sequence", "__mj_CreatedAt", "__mj_UpdatedAt")
        VALUES ('d3c32ecd-b2f2-4cc5-8878-b62e6d4b5945', 'E0238F34-2837-EF11-86D4-6045BDEE16E6', '65E7DAD5-9930-4140-9A38-2184EB0097DA', 'SourceEntityID', 'One To Many', TRUE, TRUE, 66, NOW(), NOW());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityRelationship" WHERE "ID" = '6c76d6fc-300b-408d-81bc-055f26e11997'
    ) THEN
        INSERT INTO "${mjSchema}"."EntityRelationship" ("ID", "EntityID", "RelatedEntityID", "RelatedEntityJoinField", "Type", "BundleInAPI", "DisplayInForm", "Sequence", "__mj_CreatedAt", "__mj_UpdatedAt")
        VALUES ('6c76d6fc-300b-408d-81bc-055f26e11997', 'E0238F34-2837-EF11-86D4-6045BDEE16E6', '65E7DAD5-9930-4140-9A38-2184EB0097DA', 'AssigneeEntityID', 'One To Many', TRUE, TRUE, 67, NOW(), NOW());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityRelationship" WHERE "ID" = '409edb50-0922-498b-95f5-3078b69ce6a9'
    ) THEN
        INSERT INTO "${mjSchema}"."EntityRelationship" ("ID", "EntityID", "RelatedEntityID", "RelatedEntityJoinField", "Type", "BundleInAPI", "DisplayInForm", "Sequence", "__mj_CreatedAt", "__mj_UpdatedAt")
        VALUES ('409edb50-0922-498b-95f5-3078b69ce6a9', '38248F34-2837-EF11-86D4-6045BDEE16E6', 'B08FB976-CC72-4DAC-B950-A5C86DD04267', 'OnStatusChangeActionID', 'One To Many', TRUE, TRUE, 18, NOW(), NOW());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityRelationship" WHERE "ID" = '2bca9ab1-1522-4ded-9ac7-73691b84cfd2'
    ) THEN
        INSERT INTO "${mjSchema}"."EntityRelationship" ("ID", "EntityID", "RelatedEntityID", "RelatedEntityJoinField", "Type", "BundleInAPI", "DisplayInForm", "Sequence", "__mj_CreatedAt", "__mj_UpdatedAt")
        VALUES ('2bca9ab1-1522-4ded-9ac7-73691b84cfd2', '38248F34-2837-EF11-86D4-6045BDEE16E6', 'B08FB976-CC72-4DAC-B950-A5C86DD04267', 'OnCreateActionID', 'One To Many', TRUE, TRUE, 19, NOW(), NOW());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityRelationship" WHERE "ID" = '5bf4718b-8311-4eec-a0c0-e31a80533301'
    ) THEN
        INSERT INTO "${mjSchema}"."EntityRelationship" ("ID", "EntityID", "RelatedEntityID", "RelatedEntityJoinField", "Type", "BundleInAPI", "DisplayInForm", "Sequence", "__mj_CreatedAt", "__mj_UpdatedAt")
        VALUES ('5bf4718b-8311-4eec-a0c0-e31a80533301', '38248F34-2837-EF11-86D4-6045BDEE16E6', 'B08FB976-CC72-4DAC-B950-A5C86DD04267', 'OnAssignActionID', 'One To Many', TRUE, TRUE, 20, NOW(), NOW());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityRelationship" WHERE "ID" = '78969fa0-3215-4fff-8316-83954d959dd6'
    ) THEN
        INSERT INTO "${mjSchema}"."EntityRelationship" ("ID", "EntityID", "RelatedEntityID", "RelatedEntityJoinField", "Type", "BundleInAPI", "DisplayInForm", "Sequence", "__mj_CreatedAt", "__mj_UpdatedAt")
        VALUES ('78969fa0-3215-4fff-8316-83954d959dd6', '38248F34-2837-EF11-86D4-6045BDEE16E6', 'B08FB976-CC72-4DAC-B950-A5C86DD04267', 'OnCloseActionID', 'One To Many', TRUE, TRUE, 21, NOW(), NOW());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityRelationship" WHERE "ID" = '04d5ab9f-1427-4a04-8113-217200288689'
    ) THEN
        INSERT INTO "${mjSchema}"."EntityRelationship" ("ID", "EntityID", "RelatedEntityID", "RelatedEntityJoinField", "Type", "BundleInAPI", "DisplayInForm", "Sequence", "__mj_CreatedAt", "__mj_UpdatedAt")
        VALUES ('04d5ab9f-1427-4a04-8113-217200288689', 'B08FB976-CC72-4DAC-B950-A5C86DD04267', '65E7DAD5-9930-4140-9A38-2184EB0097DA', 'IssueTypeID', 'One To Many', TRUE, TRUE, 1, NOW(), NOW());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityRelationship" WHERE "ID" = 'bbb1c55f-49e2-48ad-9e4a-666ee656741b'
    ) THEN
        INSERT INTO "${mjSchema}"."EntityRelationship" ("ID", "EntityID", "RelatedEntityID", "RelatedEntityJoinField", "Type", "BundleInAPI", "DisplayInForm", "Sequence", "__mj_CreatedAt", "__mj_UpdatedAt")
        VALUES ('bbb1c55f-49e2-48ad-9e4a-666ee656741b', '1E30141A-826F-4278-BAA9-BBE14D29E606', 'B08FB976-CC72-4DAC-B950-A5C86DD04267', 'DefaultTaskTypeID', 'One To Many', TRUE, TRUE, 4, NOW(), NOW());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityRelationship" WHERE "ID" = '2c0b564a-d076-4591-9687-f62fefbb3f75'
    ) THEN
        INSERT INTO "${mjSchema}"."EntityRelationship" ("ID", "EntityID", "RelatedEntityID", "RelatedEntityJoinField", "Type", "BundleInAPI", "DisplayInForm", "Sequence", "__mj_CreatedAt", "__mj_UpdatedAt")
        VALUES ('2c0b564a-d076-4591-9687-f62fefbb3f75', '7A94ADA9-7880-4FAE-97D8-DB0E934C3F5F', '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B', 'AuthorPersonID', 'One To Many', TRUE, TRUE, 8, NOW(), NOW());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityRelationship" WHERE "ID" = '1ce94364-82a1-44ef-8feb-0f8785691ab4'
    ) THEN
        INSERT INTO "${mjSchema}"."EntityRelationship" ("ID", "EntityID", "RelatedEntityID", "RelatedEntityJoinField", "Type", "BundleInAPI", "DisplayInForm", "Sequence", "__mj_CreatedAt", "__mj_UpdatedAt")
        VALUES ('1ce94364-82a1-44ef-8feb-0f8785691ab4', '7A94ADA9-7880-4FAE-97D8-DB0E934C3F5F', '65E7DAD5-9930-4140-9A38-2184EB0097DA', 'ReporterPersonID', 'One To Many', TRUE, TRUE, 9, NOW(), NOW());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityRelationship" WHERE "ID" = '50190acd-091e-41d6-8738-aeabcc020ddb'
    ) THEN
        INSERT INTO "${mjSchema}"."EntityRelationship" ("ID", "EntityID", "RelatedEntityID", "RelatedEntityJoinField", "Type", "BundleInAPI", "DisplayInForm", "Sequence", "__mj_CreatedAt", "__mj_UpdatedAt")
        VALUES ('50190acd-091e-41d6-8738-aeabcc020ddb', '7A94ADA9-7880-4FAE-97D8-DB0E934C3F5F', '65E7DAD5-9930-4140-9A38-2184EB0097DA', 'CreatedByPersonID', 'One To Many', TRUE, TRUE, 10, NOW(), NOW());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'a0e546ec-bea3-46e0-b5e9-21c9f6a31ae3' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = 'IssueType')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'a0e546ec-bea3-46e0-b5e9-21c9f6a31ae3',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100041,
        'IssueType',
        'Issue Type',
        NULL,
        'TEXT',
        200,
        0,
        0,
        FALSE,
        NULL,
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '9111e30e-76a3-4582-ac5c-06a7b9ac530e' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = 'Status')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '9111e30e-76a3-4582-ac5c-06a7b9ac530e',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100042,
        'Status',
        'Status',
        NULL,
        'TEXT',
        200,
        0,
        0,
        FALSE,
        NULL,
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '5b543630-4c16-4034-99de-1c4420a9cbd2' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = 'ReporterPerson')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '5b543630-4c16-4034-99de-1c4420a9cbd2',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100043,
        'ReporterPerson',
        'Reporter Person',
        NULL,
        'TEXT',
        402,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '00d07775-578d-4f35-86b6-136b9256fc30' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = 'AssigneeEntity')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '00d07775-578d-4f35-86b6-136b9256fc30',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100044,
        'AssigneeEntity',
        'Assignee Entity',
        NULL,
        'TEXT',
        510,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'd0d423b1-0148-4920-a657-5756b13364b6' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = 'SourceEntity')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'd0d423b1-0148-4920-a657-5756b13364b6',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100045,
        'SourceEntity',
        'Source Entity',
        NULL,
        'TEXT',
        510,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '7d7c497f-a10e-4ea5-8daf-50095c9fb635' OR ("EntityID" = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND "Name" = 'CreatedByPerson')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '7d7c497f-a10e-4ea5-8daf-50095c9fb635',
        '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- "Entity": "MJ_BizApps_Issues": "Issues"
        100046,
        'CreatedByPerson',
        'Created By Person',
        NULL,
        'TEXT',
        402,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '9ce5a5b6-b87a-47cf-9ffc-34c433780eed' OR ("EntityID" = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND "Name" = 'DefaultTaskType')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '9ce5a5b6-b87a-47cf-9ffc-34c433780eed',
        'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- "Entity": "MJ_BizApps_Issues": "Issue" "Types"
        100027,
        'DefaultTaskType',
        'Default Task Type',
        NULL,
        'TEXT',
        200,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'c8533e9d-5b23-49b4-9789-3f645f4573e4' OR ("EntityID" = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND "Name" = 'OnCreateAction')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'c8533e9d-5b23-49b4-9789-3f645f4573e4',
        'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- "Entity": "MJ_BizApps_Issues": "Issue" "Types"
        100028,
        'OnCreateAction',
        'On Create Action',
        NULL,
        'TEXT',
        850,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = '20b735b3-ec6a-4c5f-9027-2be6d96d9045' OR ("EntityID" = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND "Name" = 'OnStatusChangeAction')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        '20b735b3-ec6a-4c5f-9027-2be6d96d9045',
        'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- "Entity": "MJ_BizApps_Issues": "Issue" "Types"
        100029,
        'OnStatusChangeAction',
        'On Status Change Action',
        NULL,
        'TEXT',
        850,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'b82a5655-b11c-4ead-b7c0-cf61786a4101' OR ("EntityID" = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND "Name" = 'OnAssignAction')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'b82a5655-b11c-4ead-b7c0-cf61786a4101',
        'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- "Entity": "MJ_BizApps_Issues": "Issue" "Types"
        100030,
        'OnAssignAction',
        'On Assign Action',
        NULL,
        'TEXT',
        850,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'b62c4ae2-1148-402c-accc-a4dc7354ddc0' OR ("EntityID" = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND "Name" = 'OnCloseAction')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'b62c4ae2-1148-402c-accc-a4dc7354ddc0',
        'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- "Entity": "MJ_BizApps_Issues": "Issue" "Types"
        100031,
        'OnCloseAction',
        'On Close Action',
        NULL,
        'TEXT',
        850,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'f85bce40-59bb-42d8-8bb6-971c6479ba73' OR ("EntityID" = '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B' AND "Name" = 'AuthorPerson')
    ) THEN
        INSERT INTO "${mjSchema}"."EntityField"
        (
        "ID",
        "EntityID",
        "Sequence",
        "Name",
        "DisplayName",
        "Description",
        "Type",
        "Length",
        "Precision",
        "Scale",
        "AllowsNull",
        "DefaultValue",
        "AutoIncrement",
        "AllowUpdateAPI",
        "IsVirtual",
        "IsComputed",
        "RelatedEntityID",
        "RelatedEntityFieldName",
        "IsNameField",
        "IncludeInUserSearchAPI",
        "IncludeRelatedEntityNameFieldInBaseView",
        "DefaultInView",
        "IsPrimaryKey",
        "IsUnique",
        "RelatedEntityDisplayType",
        "__mj_CreatedAt",
        "__mj_UpdatedAt"
        )
        VALUES
        (
        'f85bce40-59bb-42d8-8bb6-971c6479ba73',
        '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B', -- "Entity": "MJ_BizApps_Issues": "Issue" "Comments"
        100017,
        'AuthorPerson',
        'Author Person',
        NULL,
        'TEXT',
        402,
        0,
        0,
        TRUE,
        NULL,
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        NULL,
        NULL,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        'Search',
        NOW(),
        NOW()
        );
    END IF;
END $$;


-- ===================== FK & CHECK Constraints =====================


-- Flush any pending deferred trigger events from prior DML so DDL below can proceed.
SET CONSTRAINTS ALL IMMEDIATE;

-- =============================================================================
-- 3. FOREIGN KEYS
-- =============================================================================

-- IssueType → bizapps-tasks TaskType (default work type) and core [Action] hooks
ALTER TABLE "__mj_BizAppsIssues"."IssueType"
 ADD CONSTRAINT "FK_IssueType_DefaultTaskType"
        FOREIGN KEY ("DefaultTaskTypeID") REFERENCES "__mj_BizAppsTasks"."TaskType"("ID") DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE "__mj_BizAppsIssues"."IssueType"
 ADD CONSTRAINT "FK_IssueType_OnCreateAction"
        FOREIGN KEY ("OnCreateActionID") REFERENCES ${mjSchema}."Action"("ID");

ALTER TABLE "__mj_BizAppsIssues"."IssueType"
 ADD CONSTRAINT "FK_IssueType_OnStatusChangeAction"
        FOREIGN KEY ("OnStatusChangeActionID") REFERENCES ${mjSchema}."Action"("ID");

ALTER TABLE "__mj_BizAppsIssues"."IssueType"
 ADD CONSTRAINT "FK_IssueType_OnAssignAction"
        FOREIGN KEY ("OnAssignActionID") REFERENCES ${mjSchema}."Action"("ID");

ALTER TABLE "__mj_BizAppsIssues"."IssueType"
 ADD CONSTRAINT "FK_IssueType_OnCloseAction"
        FOREIGN KEY ("OnCloseActionID") REFERENCES ${mjSchema}."Action"("ID");

-- Issue → IssueType / IssueStatus (within schema), polymorphic entity refs to
-- core Entity, reporter + creator Person (cross-schema to bizapps-common).
ALTER TABLE "__mj_BizAppsIssues"."Issue"
 ADD CONSTRAINT "FK_Issue_IssueType"
        FOREIGN KEY ("IssueTypeID") REFERENCES "__mj_BizAppsIssues"."IssueType"("ID") DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE "__mj_BizAppsIssues"."Issue"
 ADD CONSTRAINT "FK_Issue_Status"
        FOREIGN KEY ("StatusID") REFERENCES "__mj_BizAppsIssues"."IssueStatus"("ID") DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE "__mj_BizAppsIssues"."Issue"
 ADD CONSTRAINT "FK_Issue_AssigneeEntity"
        FOREIGN KEY ("AssigneeEntityID") REFERENCES ${mjSchema}."Entity"("ID");

ALTER TABLE "__mj_BizAppsIssues"."Issue"
 ADD CONSTRAINT "FK_Issue_SourceEntity"
        FOREIGN KEY ("SourceEntityID") REFERENCES ${mjSchema}."Entity"("ID");

ALTER TABLE "__mj_BizAppsIssues"."Issue"
 ADD CONSTRAINT "FK_Issue_ReporterPerson"
        FOREIGN KEY ("ReporterPersonID") REFERENCES "__mj_BizAppsCommon"."Person"("ID") DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE "__mj_BizAppsIssues"."Issue"
 ADD CONSTRAINT "FK_Issue_CreatedByPerson"
        FOREIGN KEY ("CreatedByPersonID") REFERENCES "__mj_BizAppsCommon"."Person"("ID") DEFERRABLE INITIALLY DEFERRED;

-- IssueComment → Issue (within schema), author Person (cross-schema).
ALTER TABLE "__mj_BizAppsIssues"."IssueComment"
 ADD CONSTRAINT "FK_IssueComment_Issue"
        FOREIGN KEY ("IssueID") REFERENCES "__mj_BizAppsIssues"."Issue"("ID") DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE "__mj_BizAppsIssues"."IssueComment"
 ADD CONSTRAINT "FK_IssueComment_AuthorPerson"
        FOREIGN KEY ("AuthorPersonID") REFERENCES "__mj_BizAppsCommon"."Person"("ID") DEFERRABLE INITIALLY DEFERRED;


-- ===================== Grants =====================

-- Grant EXECUTE to the MJ runtime roles (CodeGen does this automatically for its
-- generated CRUD procs; custom procs must grant explicitly). Called on the Issue
-- insert path, so grant to both roles like a create proc.
DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spAssignNextIssueNumber" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN GRANT SELECT ON "__mj_BizAppsIssues"."vwIssueNumberSequences" TO "cdp_UI", "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* Base View Permissions SQL for MJ_BizApps_Issues: Issue Number Sequences */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Number Sequences
-- Item: Permissions for vwIssueNumberSequences
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------;

DO $$ BEGIN GRANT SELECT ON "__mj_BizAppsIssues"."vwIssueNumberSequences" TO "cdp_UI", "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spCreate SQL for MJ_BizApps_Issues: Issue Number Sequences */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Number Sequences
-- Item: spCreateIssueNumberSequence
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- CREATE PROCEDURE FOR IssueNumberSequence
------------------------------------------------------------;

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spCreateIssueNumberSequence" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spCreate Permissions for MJ_BizApps_Issues: Issue Number Sequences */

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spCreateIssueNumberSequence" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spUpdate SQL for MJ_BizApps_Issues: Issue Number Sequences */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Number Sequences
-- Item: spUpdateIssueNumberSequence
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- UPDATE PROCEDURE FOR IssueNumberSequence
------------------------------------------------------------;

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spUpdateIssueNumberSequence" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spUpdateIssueNumberSequence" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* Base View SQL for MJ_BizApps_Issues: Issue Status */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Status
-- Item: vwIssueStatus
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- BASE VIEW FOR ENTITY:      MJ_BizApps_Issues: Issue Status
-----               SCHEMA:      __mj_BizAppsIssues
-----               BASE TABLE:  IssueStatus
-----               PRIMARY KEY: ID
------------------------------------------------------------;

DO $$ BEGIN GRANT SELECT ON "__mj_BizAppsIssues"."vwIssueStatus" TO "cdp_UI", "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* Base View Permissions SQL for MJ_BizApps_Issues: Issue Status */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Status
-- Item: Permissions for vwIssueStatus
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------;

DO $$ BEGIN GRANT SELECT ON "__mj_BizAppsIssues"."vwIssueStatus" TO "cdp_UI", "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spCreate SQL for MJ_BizApps_Issues: Issue Status */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Status
-- Item: spCreateIssueStatus
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- CREATE PROCEDURE FOR IssueStatus
------------------------------------------------------------;

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spCreateIssueStatus" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spCreate Permissions for MJ_BizApps_Issues: Issue Status */

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spCreateIssueStatus" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spUpdate SQL for MJ_BizApps_Issues: Issue Status */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Status
-- Item: spUpdateIssueStatus
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- UPDATE PROCEDURE FOR IssueStatus
------------------------------------------------------------;

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spUpdateIssueStatus" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spUpdateIssueStatus" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spDelete SQL for MJ_BizApps_Issues: Issue Number Sequences */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Number Sequences
-- Item: spDeleteIssueNumberSequence
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- DELETE PROCEDURE FOR IssueNumberSequence
------------------------------------------------------------;

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spDeleteIssueNumberSequence" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spDelete Permissions for MJ_BizApps_Issues: Issue Number Sequences */

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spDeleteIssueNumberSequence" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spDelete SQL for MJ_BizApps_Issues: Issue Status */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Status
-- Item: spDeleteIssueStatus
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- DELETE PROCEDURE FOR IssueStatus
------------------------------------------------------------;

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spDeleteIssueStatus" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spDelete Permissions for MJ_BizApps_Issues: Issue Status */

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spDeleteIssueStatus" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* Base View SQL for MJ_BizApps_Issues: Issue Comments */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Comments
-- Item: vwIssueComments
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- BASE VIEW FOR ENTITY:      MJ_BizApps_Issues: Issue Comments
-----               SCHEMA:      __mj_BizAppsIssues
-----               BASE TABLE:  IssueComment
-----               PRIMARY KEY: ID
------------------------------------------------------------;

DO $$ BEGIN GRANT SELECT ON "__mj_BizAppsIssues"."vwIssueComments" TO "cdp_UI", "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* Base View Permissions SQL for MJ_BizApps_Issues: Issue Comments */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Comments
-- Item: Permissions for vwIssueComments
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------;

DO $$ BEGIN GRANT SELECT ON "__mj_BizAppsIssues"."vwIssueComments" TO "cdp_UI", "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spCreate SQL for MJ_BizApps_Issues: Issue Comments */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Comments
-- Item: spCreateIssueComment
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- CREATE PROCEDURE FOR IssueComment
------------------------------------------------------------;

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spCreateIssueComment" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spCreate Permissions for MJ_BizApps_Issues: Issue Comments */

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spCreateIssueComment" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spUpdate SQL for MJ_BizApps_Issues: Issue Comments */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Comments
-- Item: spUpdateIssueComment
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- UPDATE PROCEDURE FOR IssueComment
------------------------------------------------------------;

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spUpdateIssueComment" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spUpdateIssueComment" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spDelete SQL for MJ_BizApps_Issues: Issue Comments */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Comments
-- Item: spDeleteIssueComment
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- DELETE PROCEDURE FOR IssueComment
------------------------------------------------------------;

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spDeleteIssueComment" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spDelete Permissions for MJ_BizApps_Issues: Issue Comments */

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spDeleteIssueComment" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* SQL text to update entity field related entity name field map for entity field ID 86B9EC44-D8DA-4540-9638-DB50F4D92BC4 */

DO $$ BEGIN GRANT SELECT ON "__mj_BizAppsIssues"."vwIssueTypes" TO "cdp_UI", "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* Base View Permissions SQL for MJ_BizApps_Issues: Issue Types */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Types
-- Item: Permissions for vwIssueTypes
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------;

DO $$ BEGIN GRANT SELECT ON "__mj_BizAppsIssues"."vwIssueTypes" TO "cdp_UI", "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spCreate SQL for MJ_BizApps_Issues: Issue Types */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Types
-- Item: spCreateIssueType
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- CREATE PROCEDURE FOR IssueType
------------------------------------------------------------;

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spCreateIssueType" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spCreate Permissions for MJ_BizApps_Issues: Issue Types */

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spCreateIssueType" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spUpdate SQL for MJ_BizApps_Issues: Issue Types */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Types
-- Item: spUpdateIssueType
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- UPDATE PROCEDURE FOR IssueType
------------------------------------------------------------;

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spUpdateIssueType" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spUpdateIssueType" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spDelete SQL for MJ_BizApps_Issues: Issue Types */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Types
-- Item: spDeleteIssueType
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- DELETE PROCEDURE FOR IssueType
------------------------------------------------------------;

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spDeleteIssueType" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spDelete Permissions for MJ_BizApps_Issues: Issue Types */

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spDeleteIssueType" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* SQL text to update entity field related entity name field map for entity field ID 2BDFB21A-BAF7-482D-98C5-4DFD03FF45EE */

DO $$ BEGIN GRANT SELECT ON "__mj_BizAppsIssues"."vwIssues" TO "cdp_UI", "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* Base View Permissions SQL for MJ_BizApps_Issues: Issues */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issues
-- Item: Permissions for vwIssues
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------;

DO $$ BEGIN GRANT SELECT ON "__mj_BizAppsIssues"."vwIssues" TO "cdp_UI", "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spCreate SQL for MJ_BizApps_Issues: Issues */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issues
-- Item: spCreateIssue
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- CREATE PROCEDURE FOR Issue
------------------------------------------------------------;

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spCreateIssue" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spCreate Permissions for MJ_BizApps_Issues: Issues */

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spCreateIssue" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spUpdate SQL for MJ_BizApps_Issues: Issues */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issues
-- Item: spUpdateIssue
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- UPDATE PROCEDURE FOR Issue
------------------------------------------------------------;

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spUpdateIssue" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spUpdateIssue" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spDelete SQL for MJ_BizApps_Issues: Issues */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issues
-- Item: spDeleteIssue
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- DELETE PROCEDURE FOR Issue
------------------------------------------------------------;

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spDeleteIssue" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spDelete Permissions for MJ_BizApps_Issues: Issues */

DO $$ BEGIN GRANT EXECUTE ON FUNCTION "__mj_BizAppsIssues"."spDeleteIssue" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* SQL text to delete unneeded entity fields (5 scoped entities) */


-- ===================== Comments =====================

-- Extended property (could not parse)
-- -- =============================================================================
-- -- 5. EXTENDED PROPERTIES (MS_Description) — schema, tables, and every column
-- -- =============================================================================
-- 
-- -- Schema
-- EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'BizApps Issues: reusable case / issue / ticket primitives. The shared foundation for ticketing UX (Izzy) and the destination for MJ cloud feedback.',
--     @level0type = N'SCHEMA', @level0name = N'__mj_BizAppsIssues';

COMMENT ON TABLE "__mj_BizAppsIssues"."IssueType" IS 'Lifecycle automation for a class of issue (Bug, Feature Request, Question, Feedback). Mirrors the bizapps-tasks TaskType action-hook pattern: On*ActionID columns point at core "Action" records fired at the matching lifecycle event.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueType"."ID" IS 'Unique identifier (UUID).';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueType"."Name" IS 'Display name of the issue type (unique). E.g. ';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueType"."Description" IS 'Detailed description of what this issue type represents and when to use it.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueType"."IconClass" IS 'Font Awesome (or similar) icon class shown next to issues of this type in the UI.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueType"."DefaultPriority" IS 'Priority assigned to new issues of this type when none is specified. One of Low, Medium, High, Critical.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueType"."DefaultTaskTypeID" IS 'bizapps-tasks TaskType used when an Issue of this type spawns work via IssueWorkService. NULL = let the caller choose.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueType"."OnCreateActionID" IS 'Action fired by IssueService when an Issue of this type is created.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueType"."OnStatusChangeActionID" IS 'Action fired by IssueService when an Issue of this type changes status.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueType"."OnAssignActionID" IS 'Action fired by IssueService when an Issue of this type is assigned.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueType"."OnCloseActionID" IS 'Action fired by IssueService when an Issue of this type is closed.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueType"."IsActive" IS 'Whether this issue type is available for new issues. Inactive types stay on historical issues but are hidden from selection.';

COMMENT ON TABLE "__mj_BizAppsIssues"."IssueStatus" IS 'Workflow state an Issue can be in (New, Triaged, In Progress, Resolved, Closed, ...). Seeded via metadata sync, not in this migration. Drives board columns.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueStatus"."ID" IS 'Unique identifier (UUID).';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueStatus"."Name" IS 'Display name of the status (unique). E.g. ';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueStatus"."Description" IS 'Detailed description of what this status means in the workflow.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueStatus"."Sequence" IS 'Sort order of the status on boards and in dropdowns. Lower values appear first.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueStatus"."IsDefault" IS 'Whether new issues default to this status. Exactly one status should have this set.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueStatus"."IsTerminal" IS 'Whether this is a terminal (end) state such as Closed or Won';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueStatus"."ColorCode" IS 'Hex (or token) color used to render this status as a chip / board column header.';

COMMENT ON TABLE "__mj_BizAppsIssues"."Issue" IS 'The core case / ticket / feedback record. Carries reporter, polymorphic assignee (Person or AI Agent), and a polymorphic source (any record the issue is about). Spawns bizapps-tasks Tasks for the actual work via TaskLink.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."Issue"."ID" IS 'Unique identifier (UUID).';

COMMENT ON COLUMN "__mj_BizAppsIssues"."Issue"."IssueNumber" IS 'Human-readable case identifier, format {SCOPE}-{seq} (e.g. ';

COMMENT ON COLUMN "__mj_BizAppsIssues"."Issue"."Title" IS 'Short, one-line summary of the issue.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."Issue"."Description" IS 'Full description / body of the issue (Markdown or plain text).';

COMMENT ON COLUMN "__mj_BizAppsIssues"."Issue"."IssueTypeID" IS 'The IssueType classifying this issue. Drives lifecycle action hooks and the default spawned task type.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."Issue"."StatusID" IS 'Current workflow status of the issue.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."Issue"."Severity" IS 'Impact of the issue (how bad it is): Low, Medium, High, Critical. Distinct from Priority.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."Issue"."Priority" IS 'Scheduling priority (how soon to address it): Low, Medium, High, Critical. Distinct from Severity.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."Issue"."ReporterPersonID" IS 'The Person who raised the issue, when known internally. NULL for external/anonymous reporters (use ReporterEmail).';

COMMENT ON COLUMN "__mj_BizAppsIssues"."Issue"."ReporterEmail" IS 'Email of the reporter, used when there is no linked Person (external feedback, email-in).';

COMMENT ON COLUMN "__mj_BizAppsIssues"."Issue"."AssigneeEntityID" IS 'Polymorphic assignee: the core Entity of the assignee (e.g. a Person entity or an AI Agent entity). Paired with AssigneeRecordID.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."Issue"."AssigneeRecordID" IS 'Polymorphic assignee: the primary key (as string) of the assignee record within AssigneeEntityID.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."Issue"."SourceEntityID" IS 'Polymorphic source: the core Entity of the record this issue is about (what the feedback concerns). Paired with SourceRecordID.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."Issue"."SourceRecordID" IS 'Polymorphic source: the primary key (as string) of the source record within SourceEntityID.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."Issue"."AppScope" IS 'Which app / product this issue belongs to (free-text scope tag, e.g. ';

COMMENT ON COLUMN "__mj_BizAppsIssues"."Issue"."ResolvedAt" IS 'Timestamp the issue was resolved (entered a resolved state). NULL while unresolved.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."Issue"."ClosedAt" IS 'Timestamp the issue was closed (entered a terminal state). NULL while open.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."Issue"."CreatedByPersonID" IS 'The Person who created the issue record in the system (may differ from the reporter).';

COMMENT ON TABLE "__mj_BizAppsIssues"."IssueComment" IS 'Threaded discussion entry on an Issue. Author is a Person when internal; AuthorEmail carries the address for email / external sources.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueComment"."ID" IS 'Unique identifier (UUID).';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueComment"."IssueID" IS 'The Issue this comment belongs to.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueComment"."Body" IS 'Comment body (Markdown or plain text).';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueComment"."AuthorPersonID" IS 'The Person who authored the comment, when internal. NULL for email/external authors (use AuthorEmail).';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueComment"."AuthorEmail" IS 'Email of the comment author, used when there is no linked Person.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueComment"."Source" IS 'Origin of the comment: ';

COMMENT ON TABLE "__mj_BizAppsIssues"."IssueNumberSequence" IS 'Per-scope gap-free counter backing the human-readable Issue."IssueNumber". One row per normalized ScopeCode. Maintained ONLY by spAssignNextIssueNumber — never write directly.';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueNumberSequence"."ScopeCode" IS 'The normalized (trim/UPPER) AppScope this counter is for, or ';

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueNumberSequence"."NextSequenceNumber" IS 'The next sequence value to assign for this scope. Incremented atomically (UPDLOCK/HOLDLOCK) by spAssignNextIssueNumber.';


-- ===================== Other =====================

-- NOTE: unrecognized batch type (UNKNOWN) — passed through as-is
-- =============================================================================
-- 4. STORED PROCEDURES — custom business logic (NOT CRUD; CodeGen owns spCreate/
--    spUpdate/spDelete). Hand-written here, mirroring bizapps-accounting's
--    spAssignNextBatchNumber pattern.
-- =============================================================================

---------------------------------------------------------------------------
-- 4.1 spAssignNextIssueNumber — assigns the next human-readable IssueNumber
--     for a scope. Normalizes scope (trim/UPPER, null/blank → 'ISS'),
--     atomically increments the per-scope counter under UPDLOCK/HOLDLOCK, and
--     returns the formatted unpadded {SCOPE}-{seq} (e.g. MJC-42). Called from
--     IssueEntityServer."Save"() on insert. A number is consumed when this runs;
--     if the subsequent insert rolls back the number is skipped (standard
--     sequence behavior — unique + monotonic, occasional cosmetic gaps accepted).
---------------------------------------------------------------------------
-- CREATE OR ALTER PROCEDURE __mj_BizAppsIssues.spAssignNextIssueNumber
--     @AppScope VARCHAR(255) = NULL,
--     @IssueNumber VARCHAR(50) OUTPUT
-- AS
-- BEGIN
--     SET NOCOUNT ON;
    

--     DECLARE @Scope VARCHAR(50) = NULLIF(LTRIM(RTRIM(UPPER(@AppScope))), N'');
--     IF @Scope IS NULL SET @Scope = N'ISS';

--     DECLARE @Seq INTEGER;

--     BEGIN TRAN;
--         UPDATE "__mj_BizAppsIssues"."IssueNumberSequence" WITH (UPDLOCK, HOLDLOCK)
--             SET @Seq = NextSequenceNumber, NextSequenceNumber = NextSequenceNumber + 1
--             WHERE ScopeCode = @Scope;

--         IF @@ROWCOUNT = 0
--         BEGIN
--             INSERT "__mj_BizAppsIssues"."IssueNumberSequence" (ScopeCode, NextSequenceNumber)
--                 VALUES (@Scope, 2);
--             SET @Seq = 1;
--         END
--     COMMIT;

--     SET @IssueNumber = @Scope + N'-' + CAST(@Seq AS VARCHAR(20));   -- unpadded, e.g. MJC-42
-- END;

---------------------------------------------------------------------------
-- 5.1 IssueType
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- 5.2 IssueStatus
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- 5.3 Issue
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- 5.4 IssueComment
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- 5.5 IssueNumberSequence
---------------------------------------------------------------------------

/*---------------------------------------CODEGEN-----------------------------------*/
/* SQL generated to create new entity MJ_BizApps_Issues: Issue Types */

/* SQL text to insert new entity field */

/* spUpdate Permissions for MJ_BizApps_Issues: Issue Number Sequences */

/* spUpdate Permissions for MJ_BizApps_Issues: Issue Status */

/* spUpdate Permissions for MJ_BizApps_Issues: Issue Comments */

/* spUpdate Permissions for MJ_BizApps_Issues: Issue Types */

/* spUpdate Permissions for MJ_BizApps_Issues: Issues */
