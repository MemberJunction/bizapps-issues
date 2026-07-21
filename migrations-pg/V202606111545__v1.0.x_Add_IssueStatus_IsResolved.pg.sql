-- ============================================================================
-- MemberJunction PostgreSQL Migration
-- Converted from SQL Server using TypeScript conversion pipeline
-- ============================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Schema
CREATE SCHEMA IF NOT EXISTS __mj_bizappsissues;
SET search_path TO __mj_bizappsissues, public;

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

ALTER TABLE __mj_bizappsissues."IssueStatus"
 ADD COLUMN IF NOT EXISTS "IsResolved" BOOLEAN NOT NULL DEFAULT FALSE;


-- ===================== Views =====================

DROP VIEW IF EXISTS __mj_bizappsissues."vwIssueStatus" CASCADE;
DO $do$
DECLARE
  v_target_schema CONSTANT TEXT := '__mj_bizappsissues';
  v_target_name CONSTANT TEXT := 'vwIssueStatus';
  vsql CONSTANT TEXT := $vsql$CREATE OR REPLACE VIEW __mj_bizappsissues."vwIssueStatus"
AS SELECT
    i.*
FROM
    __mj_bizappsissues."IssueStatus" AS i$vsql$;
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

-- spCreateIssueStatus: native plpgsql as emitted by MJ CodeGen (replaces the skipped T-SQL procedure).
CREATE OR REPLACE FUNCTION __mj_bizappsissues."spCreateIssueStatus"(p_id uuid DEFAULT NULL::uuid, p_name character varying DEFAULT NULL::character varying, p_description_clear boolean DEFAULT false, p_description text DEFAULT NULL::text, p_sequence integer DEFAULT NULL::integer, p_isdefault boolean DEFAULT NULL::boolean, p_isterminal boolean DEFAULT NULL::boolean, p_colorcode_clear boolean DEFAULT false, p_colorcode character varying DEFAULT NULL::character varying, p_isresolved boolean DEFAULT NULL::boolean)
 RETURNS SETOF __mj_bizappsissues."vwIssueStatus"
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_new_id UUID;
BEGIN
    v_new_id := COALESCE(p_id, gen_random_uuid());
    INSERT INTO __mj_bizappsissues."IssueStatus"
        (
            "ID",
            "Name",
                "Description",
                "Sequence",
                "IsDefault",
                "IsTerminal",
                "ColorCode",
                "IsResolved"
        )
    VALUES
        (
            v_new_id,
            p_name,
                CASE WHEN p_description_clear = true THEN NULL ELSE COALESCE(p_description, NULL) END,
                COALESCE(p_sequence, 100),
                COALESCE(p_isdefault, FALSE),
                COALESCE(p_isterminal, FALSE),
                CASE WHEN p_colorcode_clear = true THEN NULL ELSE COALESCE(p_colorcode, NULL) END,
                COALESCE(p_isresolved, FALSE)
        )
    ;

    RETURN QUERY
    SELECT * FROM __mj_bizappsissues."vwIssueStatus"
    WHERE "ID" = v_new_id;
END;
$function$;

-- spUpdateIssueStatus: native plpgsql as emitted by MJ CodeGen (replaces the skipped T-SQL procedure).
CREATE OR REPLACE FUNCTION __mj_bizappsissues."spUpdateIssueStatus"(p_id uuid, p_name character varying DEFAULT NULL::character varying, p_description_clear boolean DEFAULT false, p_description text DEFAULT NULL::text, p_sequence integer DEFAULT NULL::integer, p_isdefault boolean DEFAULT NULL::boolean, p_isterminal boolean DEFAULT NULL::boolean, p_colorcode_clear boolean DEFAULT false, p_colorcode character varying DEFAULT NULL::character varying, p_isresolved boolean DEFAULT NULL::boolean)
 RETURNS SETOF __mj_bizappsissues."vwIssueStatus"
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_updated_count INTEGER;
BEGIN
    UPDATE __mj_bizappsissues."IssueStatus"
    SET
        "Name" = COALESCE(p_name, "Name"),
        "Description" = CASE WHEN p_description_clear = true THEN NULL ELSE COALESCE(p_description, "Description") END,
        "Sequence" = COALESCE(p_sequence, "Sequence"),
        "IsDefault" = COALESCE(p_isdefault, "IsDefault"),
        "IsTerminal" = COALESCE(p_isterminal, "IsTerminal"),
        "ColorCode" = CASE WHEN p_colorcode_clear = true THEN NULL ELSE COALESCE(p_colorcode, "ColorCode") END,
        "IsResolved" = COALESCE(p_isresolved, "IsResolved")
    WHERE
        "ID" = p_id;

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;

    IF v_updated_count = 0 THEN
        -- Nothing was updated, return empty result set
        RETURN;
    END IF;

    -- Return the updated record from the base view
    RETURN QUERY
    SELECT * FROM __mj_bizappsissues."vwIssueStatus"
    WHERE "ID" = p_id;
END;
$function$;

-- spDeleteIssueStatus: native plpgsql as emitted by MJ CodeGen (replaces the skipped T-SQL procedure).
CREATE OR REPLACE FUNCTION __mj_bizappsissues."spDeleteIssueStatus"(p_id uuid)
 RETURNS TABLE("ID" uuid)
 LANGUAGE plpgsql
AS $function$
#variable_conflict use_column
DECLARE
    v_affected_count INTEGER;
BEGIN

    DELETE FROM __mj_bizappsissues."IssueStatus"
    WHERE "ID" = p_id;

    GET DIAGNOSTICS v_affected_count = ROW_COUNT;

    IF v_affected_count = 0 THEN
        RETURN QUERY SELECT NULL::UUID AS "ID";
    ELSE
        RETURN QUERY SELECT p_id AS "ID";
    END IF;
END;
$function$;


-- ===================== Triggers =====================

-- trg_update_issue_status: native row-touch trigger as emitted by MJ CodeGen (replaces the skipped T-SQL trigger)
CREATE OR REPLACE FUNCTION __mj_bizappsissues.fn_trg_update_issue_status()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW."__mj_UpdatedAt" := NOW() AT TIME ZONE 'UTC';
    RETURN NEW;
END;
$function$;
DROP TRIGGER IF EXISTS trg_update_issue_status ON __mj_bizappsissues."IssueStatus";
CREATE TRIGGER trg_update_issue_status BEFORE UPDATE ON __mj_bizappsissues."IssueStatus" FOR EACH ROW EXECUTE FUNCTION __mj_bizappsissues.fn_trg_update_issue_status();
 


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

DO $$ BEGIN GRANT SELECT ON __mj_bizappsissues."vwIssueStatus" TO "cdp_UI", "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* Base View Permissions SQL for MJ_BizApps_Issues: Issue Status */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Status
-- Item: Permissions for vwIssueStatus
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------;

DO $$ BEGIN GRANT SELECT ON __mj_bizappsissues."vwIssueStatus" TO "cdp_UI", "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
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

DO $$ BEGIN GRANT EXECUTE ON FUNCTION __mj_bizappsissues."spCreateIssueStatus" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spCreate Permissions for MJ_BizApps_Issues: Issue Status */

DO $$ BEGIN GRANT EXECUTE ON FUNCTION __mj_bizappsissues."spCreateIssueStatus" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
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

DO $$ BEGIN GRANT EXECUTE ON FUNCTION __mj_bizappsissues."spUpdateIssueStatus" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN GRANT EXECUTE ON FUNCTION __mj_bizappsissues."spUpdateIssueStatus" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
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

DO $$ BEGIN GRANT EXECUTE ON FUNCTION __mj_bizappsissues."spDeleteIssueStatus" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spDelete Permissions for MJ_BizApps_Issues: Issue Status */

DO $$ BEGIN GRANT EXECUTE ON FUNCTION __mj_bizappsissues."spDeleteIssueStatus" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* SQL text to delete unneeded entity fields (1 scoped entities) */


-- ===================== Comments =====================

COMMENT ON COLUMN __mj_bizappsissues."IssueStatus"."IsResolved" IS 'Whether this is the resolved-but-not-closed state (e.g. Resolved). Entering an IsResolved status stamps Issue."ResolvedAt". Distinct from IsTerminal: an issue can be resolved while still open for confirmation before it is closed.';


-- ===================== Other =====================

/*--------------------------------------CODEGEN--------------------------------*/

/* SQL text to update existing entities from schema */

/* spUpdate Permissions for MJ_BizApps_Issues: Issue Status */
