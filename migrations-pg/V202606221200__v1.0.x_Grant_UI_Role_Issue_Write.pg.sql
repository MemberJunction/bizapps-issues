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


-- ===================== Data (INSERT/UPDATE/DELETE) =====================

UPDATE "${mjSchema}"."EntityPermission"
SET "CanCreate" = TRUE,
    "CanUpdate" = TRUE
WHERE "EntityID" = '65e7dad5-9930-4140-9a38-2184eb0097da'
  AND "RoleID"   = 'E0AFCCEC-6A37-EF11-86D4-000D3A4E707E';

-- Issue Comments: read-only -> Create + Update (no Delete)

UPDATE "${mjSchema}"."EntityPermission"
SET "CanCreate" = TRUE,
    "CanUpdate" = TRUE
WHERE "EntityID" = '7124a46d-ea35-4c8b-bbbb-f19287ed0f9b'
  AND "RoleID"   = 'E0AFCCEC-6A37-EF11-86D4-000D3A4E707E';


-- ===================== Other =====================

-- =============================================================================
-- Grant the UI role write access to Issues + Issue Comments
-- =============================================================================
-- The baseline B-script (already applied/immutable) seeded the UI role with
-- read-only permissions (CanRead=1, all writes=0) on every Issue entity, while
-- the Developer and Integration roles got full CRUD. That left non-developer
-- (UI-role) staff unable to perform ANY ticket write — changing an assignee,
-- editing a field, filing a ticket, or commenting all failed (e.g. the
-- "Failed to change assignee" error in the ticket UI).
--
-- This grants the UI role Create + Update on the two entities staff actually
-- author against: Issues and Issue Comments. We deliberately do NOT grant
-- Delete (writes are additive/corrective for staff, not destructive) and we
-- leave the lookup tables (Issue Types, Issue Status) read-only — those are
-- curated by Developer/Integration roles.
--
-- This fix lives here (in bizapps-issues) rather than as a local per-instance
-- change so the permission set ships with the app and doesn't drift across
-- deployments.
--
-- UPDATE (not INSERT): the baseline already created these EntityPermission rows,
-- so we flip the bits on the existing UI-role rows. Idempotent and scoped by
-- the known EntityID + UI RoleID. No CodeGen involvement (pure metadata data).
--
--   UI RoleID:            E0AFCCEC-6A37-EF11-86D4-000D3A4E707E
--   Issues EntityID:      65e7dad5-9930-4140-9a38-2184eb0097da
--   Issue Comments ID:    7124a46d-ea35-4c8b-bbbb-f19287ed0f9b
-- =============================================================================

-- Issues: read-only -> Create + Update (no Delete)
