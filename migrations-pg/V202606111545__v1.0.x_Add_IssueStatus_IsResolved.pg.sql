-- ============================================================================
-- MemberJunction PostgreSQL Migration
-- Converted from SQL Server using TypeScript conversion pipeline
-- ============================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Schema
CREATE SCHEMA IF NOT EXISTS __mj_BizAppsIssues;
SET search_path TO __mj_BizAppsIssues, public;

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
-- Add IssueStatus."IsResolved"
-- =============================================================================
-- Adds a distinct "resolved-but-not-closed" flag to IssueStatus, separate from
-- IsTerminal. Entering an IsResolved status stamps Issue."ResolvedAt" (done by
-- IssueEntityServer on save); entering an IsTerminal status stamps ClosedAt.
-- An issue can be Resolved (awaiting reporter confirmation) while still open,
-- then later Closed (terminal) — two distinct lifecycle moments.
--
-- Why a separate V-migration (not an edit to the baseline B-script): the baseline
-- has already been applied + had CodeGen output appended, so it's immutable now.
-- Additive NOT NULL DEFAULT 0 column — publish-safe.
--
-- CodeGen owns the downstream work (regenerated entity subclass, base view,
-- spCreate/spUpdate, EntityField metadata) — not hand-written here.
-- =============================================================================

ALTER TABLE __mj_BizAppsIssues."IssueStatus"
 ADD COLUMN IF NOT EXISTS "IsResolved" BOOLEAN NOT NULL DEFAULT FALSE;


-- ===================== Views =====================

DROP VIEW IF EXISTS __mj_BizAppsIssues."vwIssueStatus" CASCADE;
DO $do$
DECLARE
  v_target_schema CONSTANT TEXT := '__mj_BizAppsIssues';
  v_target_name CONSTANT TEXT := 'vwIssueStatus';
  vsql CONSTANT TEXT := $vsql$CREATE OR REPLACE VIEW __mj_BizAppsIssues."vwIssueStatus"
AS SELECT
    i.*
FROM
    __mj_BizAppsIssues."IssueStatus" AS i$vsql$;
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


-- ===================== Triggers =====================

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
 


-- ===================== Data (INSERT/UPDATE/DELETE) =====================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "${mjSchema}"."EntityField" WHERE "ID" = 'ecdec461-5ee5-4e31-910f-8e4a313a8a05' OR ("EntityID" = '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4' AND "Name" = 'IsResolved')
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
        'ecdec461-5ee5-4e31-910f-8e4a313a8a05',
        '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4', -- "Entity": "MJ_BizApps_Issues": "Issue" "Status"
        100019,
        'IsResolved',
        'Is Resolved',
        'Whether this is the resolved-but-not-closed state (e.g. Resolved). Entering an IsResolved status stamps Issue."ResolvedAt". Distinct from IsTerminal: an issue can be resolved while still open for confirmation before it is closed.',
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


-- ===================== Grants =====================

DO $$ BEGIN GRANT SELECT ON __mj_BizAppsIssues."vwIssueStatus" TO "cdp_UI", "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* Base View Permissions SQL for MJ_BizApps_Issues: Issue Status */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Status
-- Item: Permissions for vwIssueStatus
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------;

DO $$ BEGIN GRANT SELECT ON __mj_BizAppsIssues."vwIssueStatus" TO "cdp_UI", "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
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

DO $$ BEGIN GRANT EXECUTE ON FUNCTION __mj_BizAppsIssues."spCreateIssueStatus" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spCreate Permissions for MJ_BizApps_Issues: Issue Status */

DO $$ BEGIN GRANT EXECUTE ON FUNCTION __mj_BizAppsIssues."spCreateIssueStatus" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
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

DO $$ BEGIN GRANT EXECUTE ON FUNCTION __mj_BizAppsIssues."spUpdateIssueStatus" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN GRANT EXECUTE ON FUNCTION __mj_BizAppsIssues."spUpdateIssueStatus" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
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

DO $$ BEGIN GRANT EXECUTE ON FUNCTION __mj_BizAppsIssues."spDeleteIssueStatus" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spDelete Permissions for MJ_BizApps_Issues: Issue Status */

DO $$ BEGIN GRANT EXECUTE ON FUNCTION __mj_BizAppsIssues."spDeleteIssueStatus" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* SQL text to delete unneeded entity fields (1 scoped entities) */


-- ===================== Comments =====================

COMMENT ON COLUMN __mj_BizAppsIssues."IssueStatus"."IsResolved" IS 'Whether this is the resolved-but-not-closed state (e.g. Resolved). Entering an IsResolved status stamps Issue."ResolvedAt". Distinct from IsTerminal: an issue can be resolved while still open for confirmation before it is closed.';


-- ===================== Other =====================

/*--------------------------------------CODEGEN--------------------------------*/

/* SQL text to update existing entities from schema */

/* spUpdate Permissions for MJ_BizApps_Issues: Issue Status */
