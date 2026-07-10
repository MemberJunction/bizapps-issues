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

-- The SQL Server twin DROPs the baseline CK_IssueComment_Source (old values:
-- internal/email/external) before re-adding it with the new value set. The
-- converter lost the DROP, which left the stale baseline constraint live —
-- and because the baseline declares the name unquoted, PG folded it to
-- ck_issuecomment_source, so the old and new constraints coexisted and their
-- intersection allowed only 'internal'. Drop both name casings, then add.
ALTER TABLE __mj_bizappsissues."IssueComment" DROP CONSTRAINT IF EXISTS ck_issuecomment_source;
ALTER TABLE __mj_bizappsissues."IssueComment" DROP CONSTRAINT IF EXISTS "CK_IssueComment_Source";
ALTER TABLE __mj_bizappsissues."IssueComment"
    ADD CONSTRAINT "CK_IssueComment_Source" CHECK ("Source" IN ('internal', 'outbound', 'inbound'));

CREATE INDEX IF NOT EXISTS "IDX_AUTO_MJ_FKEY_IssueComment_IssueID" ON __mj_bizappsissues."IssueComment" ("IssueID");

CREATE INDEX IF NOT EXISTS "IDX_AUTO_MJ_FKEY_IssueComment_AuthorPersonID" ON __mj_bizappsissues."IssueComment" ("AuthorPersonID");


-- ===================== Views =====================

-- vwIssueComments: CodeGen-canonical definition (unquoted lowercase join aliases as CodeGen emits
-- them), so a post-install codegen run sees an identical view and rewrites nothing.
DROP VIEW IF EXISTS __mj_bizappsissues."vwIssueComments" CASCADE;
DO $do$
DECLARE
  v_target_schema CONSTANT TEXT := '__mj_bizappsissues';
  v_target_name CONSTANT TEXT := 'vwIssueComments';
  vsql CONSTANT TEXT := $vsql$CREATE OR REPLACE VIEW __mj_bizappsissues."vwIssueComments"
AS  SELECT i."ID",
    i."IssueID",
    i."Body",
    i."AuthorPersonID",
    i."AuthorEmail",
    i."Source",
    i."__mj_CreatedAt",
    i."__mj_UpdatedAt",
    mjbizappscommonperson_authorpersonid."DisplayName" AS "AuthorPerson"
   FROM __mj_bizappsissues."IssueComment" i
     LEFT JOIN __mj_bizappscommon."Person" mjbizappscommonperson_authorpersonid ON i."AuthorPersonID" = mjbizappscommonperson_authorpersonid."ID"$vsql$;
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

-- spCreateIssueComment: native plpgsql as emitted by MJ CodeGen (replaces the skipped T-SQL procedure).
CREATE OR REPLACE FUNCTION __mj_bizappsissues."spCreateIssueComment"(p_id uuid DEFAULT NULL::uuid, p_issueid uuid DEFAULT NULL::uuid, p_body text DEFAULT NULL::text, p_authorpersonid_clear boolean DEFAULT false, p_authorpersonid uuid DEFAULT NULL::uuid, p_authoremail_clear boolean DEFAULT false, p_authoremail character varying DEFAULT NULL::character varying, p_source character varying DEFAULT NULL::character varying)
 RETURNS SETOF __mj_bizappsissues."vwIssueComments"
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_new_id UUID;
BEGIN
    v_new_id := COALESCE(p_id, gen_random_uuid());
    INSERT INTO __mj_bizappsissues."IssueComment"
        (
            "ID",
            "IssueID",
                "Body",
                "AuthorPersonID",
                "AuthorEmail",
                "Source"
        )
    VALUES
        (
            v_new_id,
            p_issueid,
                p_body,
                CASE WHEN p_authorpersonid_clear = true THEN NULL ELSE COALESCE(p_authorpersonid, NULL) END,
                CASE WHEN p_authoremail_clear = true THEN NULL ELSE COALESCE(p_authoremail, NULL) END,
                COALESCE(p_source, 'internal')
        )
    ;

    RETURN QUERY
    SELECT * FROM __mj_bizappsissues."vwIssueComments"
    WHERE "ID" = v_new_id;
END;
$function$;

-- spUpdateIssueComment: native plpgsql as emitted by MJ CodeGen (replaces the skipped T-SQL procedure).
CREATE OR REPLACE FUNCTION __mj_bizappsissues."spUpdateIssueComment"(p_id uuid, p_issueid uuid DEFAULT NULL::uuid, p_body text DEFAULT NULL::text, p_authorpersonid_clear boolean DEFAULT false, p_authorpersonid uuid DEFAULT NULL::uuid, p_authoremail_clear boolean DEFAULT false, p_authoremail character varying DEFAULT NULL::character varying, p_source character varying DEFAULT NULL::character varying)
 RETURNS SETOF __mj_bizappsissues."vwIssueComments"
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_updated_count INTEGER;
BEGIN
    UPDATE __mj_bizappsissues."IssueComment"
    SET
        "IssueID" = COALESCE(p_issueid, "IssueID"),
        "Body" = COALESCE(p_body, "Body"),
        "AuthorPersonID" = CASE WHEN p_authorpersonid_clear = true THEN NULL ELSE COALESCE(p_authorpersonid, "AuthorPersonID") END,
        "AuthorEmail" = CASE WHEN p_authoremail_clear = true THEN NULL ELSE COALESCE(p_authoremail, "AuthorEmail") END,
        "Source" = COALESCE(p_source, "Source")
    WHERE
        "ID" = p_id;

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;

    IF v_updated_count = 0 THEN
        -- Nothing was updated, return empty result set
        RETURN;
    END IF;

    -- Return the updated record from the base view
    RETURN QUERY
    SELECT * FROM __mj_bizappsissues."vwIssueComments"
    WHERE "ID" = p_id;
END;
$function$;

-- spDeleteIssueComment: native plpgsql as emitted by MJ CodeGen (replaces the skipped T-SQL procedure).
CREATE OR REPLACE FUNCTION __mj_bizappsissues."spDeleteIssueComment"(p_id uuid)
 RETURNS TABLE("ID" uuid)
 LANGUAGE plpgsql
AS $function$
#variable_conflict use_column
DECLARE
    v_affected_count INTEGER;
BEGIN

    DELETE FROM __mj_bizappsissues."IssueComment"
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

-- trg_update_issue_comment: native row-touch trigger as emitted by MJ CodeGen (replaces the skipped T-SQL trigger)
CREATE OR REPLACE FUNCTION __mj_bizappsissues.fn_trg_update_issue_comment()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW."__mj_UpdatedAt" := NOW() AT TIME ZONE 'UTC';
    RETURN NEW;
END;
$function$;
DROP TRIGGER IF EXISTS trg_update_issue_comment ON __mj_bizappsissues."IssueComment";
CREATE TRIGGER trg_update_issue_comment BEFORE UPDATE ON __mj_bizappsissues."IssueComment" FOR EACH ROW EXECUTE FUNCTION __mj_bizappsissues.fn_trg_update_issue_comment();


-- ===================== Data (INSERT/UPDATE/DELETE) =====================

UPDATE __mj_bizappsissues."IssueComment" SET "Source" = 'outbound' WHERE "Source" = 'email';

UPDATE __mj_bizappsissues."IssueComment" SET "Source" = 'inbound'  WHERE "Source" = 'external';

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

DO $$ BEGIN GRANT SELECT ON __mj_bizappsissues."vwIssueComments" TO "cdp_UI", "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* Base View Permissions SQL for MJ_BizApps_Issues: Issue Comments */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Comments
-- Item: Permissions for vwIssueComments
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------;

DO $$ BEGIN GRANT SELECT ON __mj_bizappsissues."vwIssueComments" TO "cdp_UI", "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
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

DO $$ BEGIN GRANT EXECUTE ON FUNCTION __mj_bizappsissues."spCreateIssueComment" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spCreate Permissions for MJ_BizApps_Issues: Issue Comments */

DO $$ BEGIN GRANT EXECUTE ON FUNCTION __mj_bizappsissues."spCreateIssueComment" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
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

DO $$ BEGIN GRANT EXECUTE ON FUNCTION __mj_bizappsissues."spUpdateIssueComment" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN GRANT EXECUTE ON FUNCTION __mj_bizappsissues."spUpdateIssueComment" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
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

DO $$ BEGIN GRANT EXECUTE ON FUNCTION __mj_bizappsissues."spDeleteIssueComment" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* spDelete Permissions for MJ_BizApps_Issues: Issue Comments */

DO $$ BEGIN GRANT EXECUTE ON FUNCTION __mj_bizappsissues."spDeleteIssueComment" TO "cdp_Developer", "cdp_Integration"; EXCEPTION WHEN others THEN NULL; END $$;
/* SQL text to delete unneeded entity fields (1 scoped entities) */


-- ===================== Comments =====================

COMMENT ON COLUMN __mj_bizappsissues."IssueComment"."Source" IS 'Direction/visibility of the comment (channel-agnostic): ''internal'' (staff-only note, never sent), ''outbound'' (customer-facing message we sent, on any channel), or ''inbound'' (a message from the customer/external side captured into the thread). The delivery channel is knowable from the ticket''s linked message, not here.';


-- ===================== Other =====================

-- Remap any existing rows to the new direction values (no-op when none exist).

/*-----------------------------CODEGEN--------------------------*/
/* SQL text to update existing entities from schema */

/* spUpdate Permissions for MJ_BizApps_Issues: Issue Comments */
