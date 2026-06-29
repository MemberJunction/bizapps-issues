-- =============================================================================
-- spAssignNextIssueNumber — PostgreSQL (PL/pgSQL) port  [PG-ONLY supplement]
-- =============================================================================
-- The canonical SQL Server definition lives inside the baseline
-- (B202606091000__…Schema_and_Tables.sql) as a hand-written T-SQL PROCEDURE with
-- an OUTPUT parameter, UPDLOCK/HOLDLOCK, and BEGIN TRAN/@@ROWCOUNT logic. The MJ
-- SS→PG converter cannot translate that custom business proc (it is NOT CodeGen
-- CRUD, so `mj codegen` does not regenerate it either), so in the converted
-- baseline (.pg.sql) the whole proc is commented out by scripts/pg-finalize.mjs
-- (Patch 2). This supplement provides the native PostgreSQL equivalent so the
-- IssueNumber feature works on PG. It has NO SQL-Server twin — `.pg-only.sql`
-- is MJ's sanctioned mechanism for a PG migration the converter cannot produce.
-- `mj migrate convert` never overwrites it (already-converted outputs are skipped).
--
-- Shape difference vs. SQL Server: PG has no clean OUTPUT-parameter EXEC idiom
-- that MJ's data provider calls, so this is a FUNCTION RETURNING TEXT (the caller
-- does `SELECT __mj_BizAppsIssues.spAssignNextIssueNumber(:scope)`).
-- SequenceService (application layer) branches on DB_PLATFORM to call the right
-- shape on each platform.
--
-- Semantics (identical to the T-SQL version):
--   * Normalize scope: trim + UPPER; null/blank -> 'ISS'.
--   * Atomically allocate the next sequence value for that scope and return the
--     unpadded '{SCOPE}-{seq}' (e.g. 'MJC-42', 'ISS-7').
--   * First call for a scope returns seq 1 and leaves the counter at 2; each
--     subsequent call returns the stored value and increments by 1.
--   * A consumed number is skipped if the caller's insert later rolls back
--     (gap-free intent is "unique + monotonic", occasional cosmetic gaps OK).
--
-- Atomicity: the T-SQL UPDLOCK/HOLDLOCK read-modify-write is replaced by an
-- INSERT … ON CONFLICT ("ScopeCode") DO UPDATE … RETURNING. ScopeCode is the
-- table's PRIMARY KEY, so the upsert is atomic under concurrency — the conflicting
-- row is row-locked for the DO UPDATE and the RETURNING reflects the post-update
-- value, with no explicit table lock required. We compute the returned seq from
-- the value BEFORE this call's increment, matching the T-SQL contract.
-- =============================================================================

CREATE OR REPLACE FUNCTION "__mj_BizAppsIssues".spAssignNextIssueNumber(
    "AppScope" VARCHAR(255) DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
AS $fn$
DECLARE
    v_scope VARCHAR(50);
    v_seq   INTEGER;
BEGIN
    -- Normalize scope: trim + upper; null/blank -> 'ISS'.
    v_scope := NULLIF(BTRIM(UPPER("AppScope")), '');
    IF v_scope IS NULL THEN
        v_scope := 'ISS';
    END IF;

    -- Atomic allocate-or-create. On first use the row is inserted with the counter
    -- already advanced to 2 and this call takes seq 1. On reuse, DO UPDATE advances
    -- the stored counter by 1; v_seq is the value this call consumed (pre-increment),
    -- derived from the RETURNING of the new (post-increment) counter minus 1.
    INSERT INTO "__mj_BizAppsIssues"."IssueNumberSequence" AS s ("ScopeCode", "NextSequenceNumber")
        VALUES (v_scope, 2)
    ON CONFLICT ("ScopeCode") DO UPDATE
        SET "NextSequenceNumber" = s."NextSequenceNumber" + 1
    RETURNING s."NextSequenceNumber" - 1 INTO v_seq;

    RETURN v_scope || '-' || v_seq::TEXT;  -- unpadded, e.g. 'MJC-42'
END;
$fn$;
