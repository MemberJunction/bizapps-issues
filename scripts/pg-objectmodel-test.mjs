// Comprehensive functional test of the BizApps Issues object model on PostgreSQL.
//
// Exercises the WRITE path (CodeGen-generated CRUD functions), the READ path (FK-join base
// views), the distinctive model features (the gap-free spassignnextissuenumber sequence
// function, cross-schema joins into bizapps-common Person / bizapps-tasks TaskType / core
// Entity, DB-level CHECK enforcement incl. the IssueComment Source value set and the paired
// Assignee/Source polymorphic columns), and full CRUD round-trips. Self-cleaning. Issues
// analog of bizapps-common's and bizapps-tasks' scripts/pg-objectmodel-test.mjs — run it
// against a one-shot install (see migrations-pg/docs/PG_INSTALL_VERIFICATION.md), no codegen
// required.
//
// Run: node scripts/pg-objectmodel-test.mjs
// Connection via env: PGHOST/PGPORT/PGDATABASE/PGUSER/PGPASSWORD
import { Pool } from 'pg';

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    console.error(`${name} must be set (no default is shipped for credentials)`);
    process.exit(1);
  }
  return value;
}

const S = '__mj_bizappsissues';
const C = '__mj_bizappscommon';
const T = '__mj_bizappstasks';
const pool = new Pool({
  host: process.env.PGHOST ?? 'localhost',
  port: +(process.env.PGPORT ?? 5436),
  user: process.env.PGUSER ?? 'mj_admin',
  // No default — a shared fallback password committed to the repo becomes a documented
  // credential. Require the caller to supply it.
  password: requireEnv('PGPASSWORD'),
  database: process.env.PGDATABASE ?? 'Issues_OneShot',
});
const q = (sql, p) => pool.query(sql, p);

let pass = 0, fail = 0;
const ok = (n) => { pass++; console.log(`  ✓ ${n}`); };
const bad = (n, d) => { fail++; console.log(`  ✗ ${n} — ${d}`); };
const check = (n, cond, d) => (cond ? ok(n) : bad(n, d));
const created = []; // {schema, table, fn, id} in reverse-dependency order for cleanup

async function createRow(schema, table, fn, args) {
  const keys = Object.keys(args);
  const id = (
    await q(
      `SELECT "ID" FROM ${schema}."${fn}"(${keys.map((k, i) => `${k} := $${i + 1}`).join(', ')})`,
      Object.values(args),
    )
  ).rows[0].ID;
  created.unshift({ schema, table, id });
  return id;
}

async function expectError(name, sql, params, needle) {
  try {
    await q(sql, params);
    bad(name, 'statement succeeded but should have violated a constraint');
  } catch (e) {
    check(name, e.message.includes(needle), e.message.slice(0, 120));
  }
}

async function main() {
  console.log('\n[1] Seeded reference data (metadata-sync migration)');
  for (const [t, want] of [['IssueStatus', 7], ['IssueType', 4]]) {
    const n = +(await q(`SELECT count(*) c FROM ${S}."${t}"`)).rows[0].c;
    check(`${t} seeded (=${want})`, n === want, `got ${n}`);
  }
  const defStatus = (await q(`SELECT "ID", "Name" FROM ${S}."IssueStatus" WHERE "IsDefault"`)).rows;
  check('exactly one default status (New)', defStatus.length === 1 && defStatus[0].Name === 'New', JSON.stringify(defStatus));
  const bugType = (await q(`SELECT "ID" FROM ${S}."IssueType" WHERE "Name"='Bug'`)).rows[0].ID;
  const newStatus = defStatus[0].ID;

  console.log('\n[2] Issue create + FK-join base view + defaults');
  const issue = await createRow(S, 'Issue', 'spCreateIssue', {
    p_title: 'TEST Issue A', p_issuetypeid: bugType, p_statusid: newStatus,
  });
  let row = (await q(`SELECT * FROM ${S}."vwIssues" WHERE "ID"=$1`, [issue])).rows[0];
  check('vwIssues FK-join IssueType name', row.IssueType === 'Bug', `got ${row.IssueType}`);
  check('vwIssues FK-join Status name', row.Status === 'New', `got ${row.Status}`);
  check('Issue defaults (Severity/Priority=Medium)', row.Severity === 'Medium' && row.Priority === 'Medium', JSON.stringify({ s: row.Severity, p: row.Priority }));

  console.log('\n[3] Cross-schema joins (common Person, tasks TaskType, core Entity)');
  const person = await createRow(C, 'Person', 'spCreatePerson', {
    p_firstname: 'TEST', p_lastname: 'Reporter', p_status: 'Active',
  });
  await q(`SELECT "ID" FROM ${S}."spUpdateIssue"(p_id := $1, p_reporterpersonid := $2)`, [issue, person]);
  row = (await q(`SELECT * FROM ${S}."vwIssues" WHERE "ID"=$1`, [issue])).rows[0];
  check('vwIssues cross-schema ReporterPerson DisplayName', row.ReporterPerson === 'TEST Reporter', `got ${row.ReporterPerson}`);

  const coreEntity = (await q(`SELECT "ID", "Name" FROM __mj."Entity" WHERE "Name"='MJ: Users'`)).rows[0];
  await q(`SELECT "ID" FROM ${S}."spUpdateIssue"(p_id := $1, p_sourceentityid := $2, p_sourcerecordid := $3)`, [issue, coreEntity.ID, 'test-record']);
  row = (await q(`SELECT * FROM ${S}."vwIssues" WHERE "ID"=$1`, [issue])).rows[0];
  check('vwIssues core-schema SourceEntity name', row.SourceEntity === 'MJ: Users', `got ${row.SourceEntity}`);

  const taskType = (await q(`SELECT "ID" FROM ${T}."TaskType" WHERE "Name"='General'`)).rows[0].ID;
  const qType = (await q(`SELECT "ID" FROM ${S}."IssueType" WHERE "Name"='Question'`)).rows[0].ID;
  await q(`SELECT "ID" FROM ${S}."spUpdateIssueType"(p_id := $1, p_defaulttasktypeid := $2)`, [qType, taskType]);
  const typeRow = (await q(`SELECT * FROM ${S}."vwIssueTypes" WHERE "ID"=$1`, [qType])).rows[0];
  check('vwIssueTypes cross-schema DefaultTaskType name (tasks)', typeRow.DefaultTaskType === 'General', `got ${typeRow.DefaultTaskType}`);
  await q(`SELECT "ID" FROM ${S}."spUpdateIssueType"(p_id := $1, p_defaulttasktypeid_clear := TRUE)`, [qType]); // restore seed state

  console.log('\n[4] IssueComment: all three Source values + view join + CHECK rejection');
  for (const src of ['internal', 'outbound', 'inbound']) {
    const c = await createRow(S, 'IssueComment', 'spCreateIssueComment', {
      p_issueid: issue, p_body: `TEST ${src} comment`, p_authorpersonid: person, p_source: src,
    });
    const cr = (await q(`SELECT * FROM ${S}."vwIssueComments" WHERE "ID"=$1`, [c])).rows[0];
    check(`comment Source='${src}' + AuthorPerson join`, cr.Source === src && cr.AuthorPerson === 'TEST Reporter', JSON.stringify({ s: cr.Source, a: cr.AuthorPerson }));
  }
  await expectError(
    "CHECK rejects legacy Source 'email'",
    `SELECT "ID" FROM ${S}."spCreateIssueComment"(p_issueid := $1, p_body := 'bad', p_source := 'email')`,
    [issue], 'CK_IssueComment_Source',
  );

  console.log('\n[5] Issue CHECK constraints');
  await expectError(
    'CHECK rejects invalid Severity',
    `SELECT "ID" FROM ${S}."spCreateIssue"(p_title := 'bad', p_issuetypeid := $1, p_statusid := $2, p_severity := 'Extreme')`,
    [bugType, newStatus], 'ck_issue_severity',
  );
  await expectError(
    'CHECK rejects Assignee entity without record (paired columns)',
    `SELECT "ID" FROM ${S}."spUpdateIssue"(p_id := $1, p_assigneeentityid := $2)`,
    [issue, coreEntity.ID], 'ck_issue_assignee',
  );

  console.log('\n[6] Gap-free IssueNumber sequence function');
  const n1 = (await q(`SELECT ${S}.spassignnextissuenumber('ISS') n`)).rows[0].n;
  const n2 = (await q(`SELECT ${S}.spassignnextissuenumber('ISS') n`)).rows[0].n;
  const n3 = (await q(`SELECT ${S}.spassignnextissuenumber('TESTSCOPE') n`)).rows[0].n;
  check('sequential per scope (ISS-1, ISS-2)', n1 === 'ISS-1' && n2 === 'ISS-2', `${n1}, ${n2}`);
  check('independent counter per scope (TESTSCOPE-1)', n3 === 'TESTSCOPE-1', n3);
  const counters = (await q(`SELECT "ScopeCode", "NextSequenceNumber" FROM ${S}."IssueNumberSequence" ORDER BY 1`)).rows;
  check('IssueNumberSequence counters persisted', JSON.stringify(counters) === JSON.stringify([{ ScopeCode: 'ISS', NextSequenceNumber: 3 }, { ScopeCode: 'TESTSCOPE', NextSequenceNumber: 2 }]), JSON.stringify(counters));
  await q(`DELETE FROM ${S}."IssueNumberSequence"`); // counters are test residue on a fresh install

  console.log('\n[7] Update round-trip + row-touch trigger');
  const before = (await q(`SELECT "__mj_UpdatedAt" u FROM ${S}."Issue" WHERE "ID"=$1`, [issue])).rows[0].u;
  await new Promise((r) => setTimeout(r, 20));
  const upd = (await q(`SELECT * FROM ${S}."spUpdateIssue"(p_id := $1, p_title := 'TEST Issue A v2', p_priority := 'High')`, [issue])).rows[0];
  check('spUpdateIssue returns updated row from view', upd.Title === 'TEST Issue A v2' && upd.Priority === 'High', JSON.stringify({ t: upd.Title, p: upd.Priority }));
  const after = (await q(`SELECT "__mj_UpdatedAt" u FROM ${S}."Issue" WHERE "ID"=$1`, [issue])).rows[0].u;
  check('fn_trg_update_issue bumped __mj_UpdatedAt', new Date(after) > new Date(before), `${before} -> ${after}`);

  console.log('\n[8] Cleanup via spDelete*');
  let cleaned = 0;
  created.sort((a, b) => (a.schema === C) - (b.schema === C)); // Person last — Issue FKs reference it
  for (const r of created) {
    const fn = r.schema === C ? 'spDeletePerson' : r.table === 'IssueComment' ? 'spDeleteIssueComment' : 'spDeleteIssue';
    const res = await q(`SELECT * FROM ${r.schema}."${fn}"($1)`, [r.id]);
    if (res.rowCount === 1) cleaned++;
  }
  check(`spDelete* removed all ${created.length} created rows`, cleaned === created.length, `cleaned ${cleaned}`);
  const leftovers = +(
    await q(
      `SELECT (SELECT count(*) FROM ${S}."Issue" WHERE "Title" LIKE 'TEST%') + (SELECT count(*) FROM ${S}."IssueComment" WHERE "Body" LIKE 'TEST%') + (SELECT count(*) FROM ${C}."Person" WHERE "FirstName"='TEST') + (SELECT count(*) FROM ${S}."IssueNumberSequence") c`,
    )
  ).rows[0].c;
  check('no TEST leftovers', leftovers === 0, `found ${leftovers}`);

  console.log(`\nRESULT: ${pass} passed, ${fail} failed`);
  await pool.end();
  process.exit(fail ? 1 : 0);
}

main().catch(async (e) => {
  console.error('FATAL:', e);
  await pool.end();
  process.exit(1);
});
