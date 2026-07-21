# Verifying BizApps Issues on PostgreSQL (one-shot install, no CodeGen)

This runbook simulates what `mj app install` does to a PostgreSQL database and
verifies that the app is **fully functional without ever running `mj codegen`**.
It is the Issues analog of bizapps-common's and bizapps-tasks'
`migrations-pg/docs/PG_INSTALL_VERIFICATION.md` — same contract, plus the two
dependency apps (`mj-bizapps-common`, `mj-bizapps-tasks`) that Issues' FKs
require (`Person`, `TaskType`).

Why simulate instead of running the real command? `mj app install` downloads
the app's migrations from the **latest GitHub release**. To test unreleased
changes to `migrations-pg/`, you run the same database steps the installer
performs — mapped 1:1 from `@memberjunction/open-app-engine`'s
`install-orchestrator` — but point the migration step at your local branch.
Once a release ships, step 3 collapses back to the real `mj app install`
(which installs the dependency apps first, in manifest order).

Background: on SQL Server, CodeGen's DDL (CRUD sprocs, views, triggers, grants)
is appended into the migrations at authoring time, so an install is complete on
its own. The PG conversion pipeline cannot translate T-SQL procedures
(`-- SKIPPED: procedure (auto-conversion not supported)`), so historically a PG
install was incomplete until a consumer ran `mj codegen`. The `migrations-pg/`
files in this repo now carry CodeGen's native plpgsql directly (extracted
verbatim from a post-codegen v5.44 database — CodeGen's fixed point), which is
what makes the one-shot install work and makes a subsequent codegen run a no-op.

## 0. Fresh PostgreSQL (throwaway container)

```bash
docker run -d --name iss-pg-test \
  -e POSTGRES_USER=mj_admin -e POSTGRES_PASSWORD=<pw> \
  -e POSTGRES_DB=Issues_OneShot -p 5436:5432 postgres:17
```

## 1. Point the MJ CLI at it

Shell exports take precedence over `.env`, so nothing in the repo needs editing:

```bash
export DB_PLATFORM=postgresql DB_HOST=localhost DB_PORT=5436 \
  DB_DATABASE=Issues_OneShot DB_USERNAME=mj_admin DB_PASSWORD=<pw> \
  CODEGEN_DB_USERNAME=mj_admin CODEGEN_DB_PASSWORD=<pw> DB_ENCRYPT=false
```

`CODEGEN_DB_*` is required even for migrate — the CLI opens its admin
connection with those credentials.

## 2. Platform install (the consumer's `mj migrate`)

```bash
npx mj migrate --tag v5.44.0        # expect: 61 applied on a virgin DB
```

Do **not** run plain `npx mj migrate` — without `--tag` it uses this repo's
local migrations directory (the app's own), not MJ core's.

## 3. Simulate `mj app install` — dependencies first, then Issues

**Run each app's migrate from its own repo directory** — the CLI resolves
`mj.config.cjs` and `migrations-pg/` from the current working directory, so a
migrate launched from the wrong repo applies the wrong app's migrations.

```bash
# --- dependency: mj-bizapps-common (from the bizapps-common repo) ---
psql -h localhost -p 5436 -U mj_admin -d Issues_OneShot \
  -c 'CREATE SCHEMA IF NOT EXISTS __mj_bizappscommon;'
(cd ../bizapps-common && npx mj migrate --schema __mj_BizAppsCommon --dir ./migrations-pg)   # 7 applied

# --- dependency: mj-bizapps-tasks (from the bizapps-tasks repo) ---
psql -h localhost -p 5436 -U mj_admin -d Issues_OneShot \
  -c 'CREATE SCHEMA IF NOT EXISTS __mj_bizappstasks;'
(cd ../bizapps-tasks && npx mj migrate --schema __mj_BizAppsTasks --dir ./migrations-pg)     # 5 applied

# --- Issues itself ---
# [Schema] HandleSchemaCreation
psql -h localhost -p 5436 -U mj_admin -d Issues_OneShot \
  -c 'CREATE SCHEMA IF NOT EXISTS __mj_bizappsissues;'

# [Schema] PersistCanonicalSchemaName — expect "UPDATE 0". The installer fires
# this BEFORE migrations, so it always misses on a fresh install. That is why
# the CodeGen_Metadata_Backfill migration sets CanonicalSchemaName itself.
psql -h localhost -p 5436 -U mj_admin -d Issues_OneShot -c \
  "UPDATE __mj.\"SchemaInfo\" SET \"CanonicalSchemaName\"='__mj_BizAppsIssues'
   WHERE LOWER(\"SchemaName\")=LOWER('__mj_bizappsissues');"

# [Migration] HandleMigrations — the app's PG migrations from YOUR branch
npx mj migrate --schema __mj_BizAppsIssues --dir ./migrations-pg   # expect: 7 applied
# (V202607101200 CodeGen_Metadata_Backfill.pgonly runs last; the history table
# gains one extra row for flyway's schema-creation entry)

# [Record] RecordInstallationAtomically + finalize Status=Active
psql -h localhost -p 5436 -U mj_admin -d Issues_OneShot -c \
  "INSERT INTO __mj.\"OpenApp\" (\"ID\",\"Name\",\"DisplayName\",\"Version\",\"Publisher\",
    \"RepositoryURL\",\"MJVersionRange\",\"ManifestJSON\",\"SchemaName\",\"InstalledByUserID\",\"Status\")
   SELECT gen_random_uuid(),'mj-bizapps-issues','Issues','<version>','MemberJunction',
    'https://github.com/MemberJunction/bizapps-issues','>=5.40.2 <6.0.0','{}',
    '__mj_BizAppsIssues',(SELECT \"ID\" FROM __mj.\"User\" LIMIT 1),'Active';"
```

**Do not run codegen.** That is the point of the test.

Post-release, this whole step is one command (the installer walks the
`mj-app.json` dependency graph itself):

```bash
npx mj app install https://github.com/MemberJunction/bizapps-issues \
  --dangerously-ignore-dbl-underscore-schema-rule
```

(The flag is required because the app's schema starts with `__mj_`. The
installer's final "add packages to host project" step only succeeds inside a
real MJ host project — the database-side steps complete regardless.)

## 4. Verify everything is there

```sql
-- expected values in comments
SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = '__mj_bizappsissues' AND p.proname ILIKE 'sp%';       -- 16
 -- (15 CRUD functions + spassignnextissuenumber)

SELECT count(*) FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
 JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE NOT t.tgisinternal AND n.nspname = '__mj_bizappsissues';          -- 5

SELECT "CanonicalSchemaName" FROM __mj."SchemaInfo"
 WHERE "SchemaName" = '__mj_bizappsissues';                              -- __mj_BizAppsIssues

SELECT count(*) FROM __mj."vwEntities"
 WHERE "SchemaName" = '__mj_bizappsissues'
   AND "ClassName" LIKE 'mjBizAppsIssues%';                              -- 5 (and 0 lowercase)

SELECT (SELECT count(*) FROM __mj_bizappsissues."IssueStatus"),          -- 7
       (SELECT count(*) FROM __mj_bizappsissues."IssueType");            -- 4
```

Then the live proof:

```bash
# Functional suite — connection via PGHOST/PGPORT/PGDATABASE/PGUSER/PGPASSWORD
node scripts/pg-objectmodel-test.mjs      # expect: RESULT: 22 passed, 0 failed
```

## 5. Optional: prove codegen is a no-op

Run `npx mj codegen`, then re-run every query in step 4 — identical numbers.
A stronger check snapshots every function/view/trigger definition hash plus all
`__mj` metadata rows for the app before and after: the diff is empty.

CodeGen will rewrite this repo's generated TypeScript with PG-flavored doc
comments — restore them afterward; they are not part of the test:

```bash
git checkout -- 'packages/Entities/src/generated' 'packages/Server/src/generated' \
  'packages/Angular/src/lib/generated'
rm -rf temp_sql_scripts
```

## Things that look wrong but aren't

- **First codegen on a virgin MJ core reconciles a few CORE metadata rows**
  (`__mj` schema). That is MJ core's own migrations not shipping their codegen
  metadata — the same platform gap this repo fixed for its app schema — and it
  is outside Issues' control. The Issues acceptance criterion is that **no
  `__mj_bizappsissues` object and no app-entity metadata row changes**; that
  diff is empty. (Same applies to the dependency apps' schemas — check them
  against *their* repos' runbooks, not this one.)
- **Keyless CodeGen logs `No suitable model found` for the
  CK_IssueNumberSequence check-constraint parser.** Non-fatal: without AI
  credentials CodeGen cannot generate the NextSequenceNumber field validator,
  writes nothing, and completes. No validator ships in
  `@mj-biz-apps/issues-entities` and none exists on the SQL Server side either,
  so this is parity, not a gap. A keyed codegen run may add that one
  GeneratedCode row — exactly as it would on SQL Server today.
- **First codegen adds four `GRANT EXECUTE ... TO cdp_UI`** on the write
  functions (spCreate/spUpdate for Issue and IssueComment) — CodeGen deriving
  DB grants from the UI role's CanCreate/CanUpdate set by the
  Grant_UI_Role_Issue_Write migration. Deliberately not shipped in the
  backfill: the SQL Server migrations don't carry them either, and hand-adding
  them on PG only would break migration parity. They arrive in the next
  CodeGen_Run migration on both platforms.
- **Two SchemaInfo rows** (`__mj_bizappsissues` + `__mj_BizAppsIssues`): the
  second is what CodeGen auto-creates keyed by the canonical name (its
  newEntityDefaults config references the schema that way); the backfill
  migration pre-creates it with a pinned ID so codegen has nothing to add.
- **Flyway history schema casing**: `mj migrate --schema __mj_BizAppsIssues`
  creates the history table in a quoted `"__mj_BizAppsIssues"` schema, while
  the real installer uses the lowercase physical schema. Cosmetic CLI
  inconsistency; affects nothing.
- **`spassignnextissuenumber` is folded lowercase** (no quoted PascalCase
  twin). Intentional: the hand-written `V202606091001__…pg-only.sql` declares
  it unquoted so `SequenceService`'s unquoted `SELECT … spassignnextissuenumber(…)`
  call resolves. The baseline's quoted
  `GRANT EXECUTE ON FUNCTION "spAssignNextIssueNumber"` no-ops silently
  (exception-swallowed) — harmless, because PostgreSQL grants EXECUTE on
  functions to PUBLIC by default.

## Maintenance contract

The plpgsql in `migrations-pg/` is CodeGen's own emission, frozen at v5.44.
When a future schema change regenerates any CRUD function, view, or trigger,
the new definition must be captured into the corresponding PG migration (the
manual PG analog of what `appendOutputCode` does automatically for T-SQL).
Seed data must be authored as plain idempotent INSERTs (`ON CONFLICT DO
NOTHING`) — the converter cannot transform `EXEC spCreate*` data calls and the
CRUD functions they name don't exist at migration time on a platform where
CodeGen output isn't baked. The no-op check in step 5 is the regression test
for all of this: if codegen changes anything after a fresh install, a migration
is missing codegen output.

## Cleanup

```bash
docker rm -f iss-pg-test
```
