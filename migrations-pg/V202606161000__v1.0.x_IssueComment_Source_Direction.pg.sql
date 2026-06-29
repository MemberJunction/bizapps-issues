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

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'CK_IssueComment_Source'
        AND conrelid = '"__mj_BizAppsIssues"."IssueComment"'::regclass
    ) THEN
        ALTER TABLE "__mj_BizAppsIssues"."IssueComment"
        ADD CONSTRAINT "CK_IssueComment_Source" CHECK ("Source" IN ('internal', 'outbound', 'inbound'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS "IDX_AUTO_MJ_FKEY_IssueComment_IssueID" ON "__mj_BizAppsIssues"."IssueComment" ("IssueID");

CREATE INDEX IF NOT EXISTS "IDX_AUTO_MJ_FKEY_IssueComment_AuthorPersonID" ON "__mj_BizAppsIssues"."IssueComment" ("AuthorPersonID");


-- ===================== Views =====================

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


-- ===================== Stored Procedures (sp*) =====================

-- SKIPPED: procedure (auto-conversion not supported)
-- CREATE PROCEDURE "__mj_BizAppsIssues"."spCreateIssueComment"
--     @ID UUID = NULL,
--     @IssueID UUID,
--     @Body TEXT,
--     @AuthorPersonID_Clear bit = 0,
--     @AuthorPers...

-- SKIPPED: procedure (auto-conversion not supported)
-- CREATE PROCEDURE "__mj_BizAppsIssues"."spUpdateIssueComment"
--     @ID UUID,
--     @IssueID UUID = NULL,
--     @Body TEXT = NULL,
--     @AuthorPersonID_Clear bit = 0,
--     @Aut...

-- SKIPPED: procedure (auto-conversion not supported)
-- CREATE PROCEDURE "__mj_BizAppsIssues"."spDeleteIssueComment"
--     @ID UUID
-- AS
-- BEGIN
--     SET NOCOUNT ON;
-- 
--     DELETE FROM
--         "__mj_BizAppsIssues"."IssueComment"
--     WHERE
--         "ID" =...


-- ===================== Triggers =====================

-- SKIPPED: trigger (auto-conversion not supported)
-- CREATE TRIGGER __mj_BizAppsIssues.trgUpdateIssueComment
-- ON "__mj_BizAppsIssues"."IssueComment"
-- AFTER UPDATE
-- AS
-- BEGIN
--     SET NOCOUNT ON;
--     UPDATE
--         "__mj_BizAppsIssues"."IssueComment"
--     SE


-- ===================== Data (INSERT/UPDATE/DELETE) =====================

UPDATE "__mj_BizAppsIssues"."IssueComment" SET "Source" = 'outbound' WHERE "Source" = 'email';

UPDATE "__mj_BizAppsIssues"."IssueComment" SET "Source" = 'inbound'  WHERE "Source" = 'external';

DELETE FROM "${mjSchema}"."EntityFieldValue" WHERE "ID"='E875C064-3D9D-407E-A4E5-C27C1F793206';

/* SQL text to delete entity field value ID D954BA16-F348-4746-A7A7-5273C3EF3834 */

DELETE FROM "${mjSchema}"."EntityFieldValue" WHERE "ID"='D954BA16-F348-4746-A7A7-5273C3EF3834';

/* SQL text to insert entity field value with ID d5e3cbda-e027-488d-b379-2f56d5968edd */

INSERT INTO "${mjSchema}"."EntityFieldValue"
                                       ("ID", "EntityFieldID", "Sequence", "Value", "Code", "__mj_CreatedAt", "__mj_UpdatedAt")
                                    VALUES
                                       ('d5e3cbda-e027-488d-b379-2f56d5968edd', '89D0ECAE-49F6-4730-B9E4-1F0CFE373571', 1, 'inbound', 'inbound', NOW(), NOW());

/* SQL text to insert entity field value with ID d9d4811d-336e-4361-b8e2-3269c6c95fbe */

INSERT INTO "${mjSchema}"."EntityFieldValue"
                                       ("ID", "EntityFieldID", "Sequence", "Value", "Code", "__mj_CreatedAt", "__mj_UpdatedAt")
                                    VALUES
                                       ('d9d4811d-336e-4361-b8e2-3269c6c95fbe', '89D0ECAE-49F6-4730-B9E4-1F0CFE373571', 3, 'outbound', 'outbound', NOW(), NOW());

/* SQL text to update entity field value sequence */

UPDATE "${mjSchema}"."EntityFieldValue" SET "Sequence"=2 WHERE "ID"='CB674C9D-5DC8-42B4-B37B-59CB1CC1A81C';

/* SQL text to sync schema info from database schemas */


-- ===================== Grants =====================

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
/* SQL text to delete unneeded entity fields (1 scoped entities) */


-- ===================== Comments =====================

COMMENT ON COLUMN "__mj_BizAppsIssues"."IssueComment"."Source" IS 'Direction/visibility of the comment (channel-agnostic): ';


-- ===================== Other =====================

-- Remap any existing rows to the new direction values (no-op when none exist).

/*-----------------------------CODEGEN--------------------------*/
/* SQL text to update existing entities from schema */

/* spUpdate Permissions for MJ_BizApps_Issues: Issue Comments */
