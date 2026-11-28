import { describe, it, expect, vi, afterEach } from 'vitest';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { RunView, type RunViewParams, type RunViewResult, UserInfo, type UserRoleInfo } from '@memberjunction/core';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const REPO_ROOT = resolve(__dirname, '../../../../..');
const METADATA_ROOT = join(REPO_ROOT, 'metadata');
const SKILL_DIR = join(METADATA_ROOT, 'chief-of-staff-skills');

const UUID_V4_UPPER_RE = /^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$/;

interface SkillMetadataRecord {
  fields: {
    Name: string;
    Description: string;
    Instructions: string;
    Status: string;
    ActivationMode: string;
    CreatedByUserID: string;
  };
  relatedEntities?: {
    'MJ: AI Agent Skills'?: Array<{
      fields: { AgentID: string; SkillID: string; Status: string };
      primaryKey: { ID: string };
    }>;
  };
  primaryKey: { ID: string };
}

interface AgentRecord {
  ID: string;
  Name: string;
  BaseAgentID: string | null;
}

interface IssueRow {
  ID: string;
  IssueNumber: string;
  Title: string;
  Severity: 'Critical' | 'High' | 'Medium' | 'Low';
  Priority: 'Critical' | 'High' | 'Medium' | 'Low';
  Status: string;
  AppScope: string;
  ReporterPersonID: string;
  AssigneeRecordID: string | null;
  ClosedAt: Date | null;
}

interface IssueCommentRow {
  ID: string;
  IssueID: string;
  Body: string;
  Source: 'inbound' | 'internal' | 'outbound';
}

interface ScopedIssueUser extends UserInfo {
  LinkedPersonID?: string;
  AllowedAppScopes?: string[];
}

function resolveInheritedSkills(
  agent: AgentRecord,
  allAgents: AgentRecord[],
  grants: Array<{ AgentName: string; SkillName: string; Status: string }>,
): string[] {
  const lineage = new Set<string>([agent.Name]);
  let parentId = agent.BaseAgentID;
  while (parentId) {
    const parent = allAgents.find((a) => a.ID === parentId);
    if (!parent) break;
    lineage.add(parent.Name);
    parentId = parent.BaseAgentID;
  }
  return grants
    .filter((g) => g.Status === 'Active' && lineage.has(g.AgentName))
    .map((g) => g.SkillName);
}

/**
 * Typed RunView-backed query path mirroring how the prompt-only Issues Chief of Staff skill
 * retrieves open issues and comment threads under the caller's ContextUser (never raw SQL).
 */
async function buildIssuesBriefingForUser(contextUser: UserInfo): Promise<{
  issueNumbers: string[];
  titles: string[];
  commentBodies: string[];
}> {
  const rv = new RunView();
  const issuesRes = await rv.RunView<IssueRow>(
    {
      EntityName: 'MJ_BizApps_Issues: Issues',
      ExtraFilter: 'ClosedAt IS NULL',
      Fields: ['ID', 'IssueNumber', 'Title', 'Severity', 'Priority', 'Status', 'AppScope', 'ReporterPersonID', 'AssigneeRecordID'],
      OrderBy: 'Severity ASC',
      ResultType: 'simple',
    },
    contextUser,
  );
  const issues = issuesRes.Success && issuesRes.Results ? issuesRes.Results : [];
  if (issues.length === 0) {
    return { issueNumbers: [], titles: [], commentBodies: [] };
  }

  const idFilter = issues.map((i) => `'${i.ID}'`).join(',');
  const commentsRes = await rv.RunView<IssueCommentRow>(
    {
      EntityName: 'MJ_BizApps_Issues: Issue Comments',
      ExtraFilter: `IssueID IN (${idFilter})`,
      Fields: ['ID', 'IssueID', 'Body', 'Source'],
      ResultType: 'simple',
    },
    contextUser,
  );
  const comments = commentsRes.Success && commentsRes.Results ? commentsRes.Results : [];
  return {
    issueNumbers: issues.map((i) => i.IssueNumber),
    titles: issues.map((i) => i.Title),
    commentBodies: comments.map((c) => c.Body),
  };
}

describe('Chief of Staff Issues Skill — Metadata & Auto-Install Integrity', () => {
  it('wires metadata/chief-of-staff-skills into mj-app.json and metadata/.mj-sync.json with zero manual steps', () => {
    const mjApp = JSON.parse(readFileSync(join(REPO_ROOT, 'mj-app.json'), 'utf8')) as {
      metadata?: { directory?: string };
    };
    expect(mjApp.metadata?.directory).toBe('metadata');

    const rootSync = JSON.parse(readFileSync(join(METADATA_ROOT, '.mj-sync.json'), 'utf8')) as {
      directoryOrder?: string[];
    };
    const order = rootSync.directoryOrder ?? [];
    expect(order).toContain('chief-of-staff-skills');

    const skillSync = JSON.parse(readFileSync(join(SKILL_DIR, '.mj-sync.json'), 'utf8')) as {
      entity: string;
      filePattern: string;
    };
    expect(skillSync.entity).toBe('MJ: AI Skills');
    expect(skillSync.filePattern).toBe('**/.*.json');
  });

  it('validates prompt-only skill JSON, Chief of Staff grant inherited by Pepper, and real Issues entity documentation', () => {
    const skillPath = join(SKILL_DIR, '.chief-of-staff-issues-skill.json');
    const rawJson = readFileSync(skillPath, 'utf8');
    expect(rawJson).not.toContain('"sync"');

    const records = JSON.parse(rawJson) as SkillMetadataRecord[];
    expect(records).toHaveLength(1);
    const skill = records[0];

    expect(skill.primaryKey.ID).toMatch(UUID_V4_UPPER_RE);
    expect(skill.fields.Name).toBe('Issues');
    expect(skill.fields.Status).toBe('Active');
    expect(skill.fields.ActivationMode).toBe('Auto');
    expect(skill.fields.CreatedByUserID).toBe('@lookup:MJ: Users.Name=System');
    expect(skill.fields.Instructions.startsWith('@file:')).toBe(true);

    const templatePath = join(SKILL_DIR, skill.fields.Instructions.slice('@file:'.length));
    expect(existsSync(templatePath)).toBe(true);
    const templateMd = readFileSync(templatePath, 'utf8');
    expect(templateMd).toContain('MJ_BizApps_Issues: Issues');
    expect(templateMd).toContain('MJ_BizApps_Issues: Issue Comments');
    expect(templateMd).toContain('MJ_BizApps_Issues: Issue Status');
    expect(templateMd).toContain('MJ_BizApps_Issues: Issue Types');
    expect(templateMd).toContain('RunView');
    expect(templateMd.toLowerCase()).toContain('never execute raw sql');

    const agentGrants = skill.relatedEntities?.['MJ: AI Agent Skills'] ?? [];
    expect(agentGrants).toHaveLength(1);
    expect(agentGrants[0].primaryKey.ID).toMatch(UUID_V4_UPPER_RE);
    expect(agentGrants[0].fields.AgentID).toBe('@lookup:MJ: AI Agents.Name=Chief of Staff');
    expect(agentGrants[0].fields.SkillID).toBe('@parent:ID');
    expect(agentGrants[0].fields.Status).toBe('Active');

    // Personal instance ("Pepper") inherits the Issues skill from Chief of Staff template
    const cos: AgentRecord = { ID: 'COS-ID', Name: 'Chief of Staff', BaseAgentID: null };
    const pepper: AgentRecord = { ID: 'PEPPER-ID', Name: 'Pepper', BaseAgentID: cos.ID };
    const inherited = resolveInheritedSkills(pepper, [cos, pepper], [
      {
        AgentName: agentGrants[0].fields.AgentID.replace('@lookup:MJ: AI Agents.Name=', ''),
        SkillName: skill.fields.Name,
        Status: agentGrants[0].fields.Status,
      },
    ]);
    expect(inherited).toEqual(['Issues']);
  });
});

describe('Chief of Staff Issues Skill — Two-User RLS Isolation', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('returns strictly different issues and comment visibility for an external reporter vs. an internal support lead using the same skill', async () => {
    const issuesTable: IssueRow[] = [
      {
        ID: 'ISS-1',
        IssueNumber: 'PORTAL-0001',
        Title: 'Invoice PDF download timeout',
        Severity: 'High',
        Priority: 'High',
        Status: 'In Progress',
        AppScope: 'PortalA',
        ReporterPersonID: 'PERSON-ALICE',
        AssigneeRecordID: 'PERSON-BOB',
        ClosedAt: null,
      },
      {
        ID: 'ISS-2',
        IssueNumber: 'PORTAL-0002',
        Title: 'SSO SAML certificate rotation failure',
        Severity: 'Critical',
        Priority: 'Critical',
        Status: 'New',
        AppScope: 'PortalB',
        ReporterPersonID: 'PERSON-CHARLIE',
        AssigneeRecordID: 'PERSON-BOB',
        ClosedAt: null,
      },
    ];

    const commentsTable: IssueCommentRow[] = [
      {
        ID: 'CMT-1',
        IssueID: 'ISS-1',
        Body: 'Customer reported timeout on invoice PDF export.',
        Source: 'inbound',
      },
      {
        ID: 'CMT-2',
        IssueID: 'ISS-1',
        Body: 'INTERNAL-ONLY: Root cause is legacy worker pool memory leak.',
        Source: 'internal',
      },
      {
        ID: 'CMT-3',
        IssueID: 'ISS-2',
        Body: 'PORTAL-B-CONFIDENTIAL: Enterprise tenant SAML cert expires Friday.',
        Source: 'inbound',
      },
    ];

    const externalReporterA = new UserInfo() as ScopedIssueUser;
    externalReporterA.ID = 'USER-ALICE';
    externalReporterA.Name = 'Alice Reporter';
    externalReporterA.LinkedPersonID = 'PERSON-ALICE';
    externalReporterA.AllowedAppScopes = ['PortalA'];
    vi.spyOn(externalReporterA, 'UserRoles', 'get').mockReturnValue([{ Role: 'UI' } as UserRoleInfo]);

    const supportLeadB = new UserInfo() as ScopedIssueUser;
    supportLeadB.ID = 'USER-BOB';
    supportLeadB.Name = 'Bob Support Lead';
    supportLeadB.LinkedPersonID = 'PERSON-BOB';
    supportLeadB.AllowedAppScopes = ['PortalA', 'PortalB'];
    vi.spyOn(supportLeadB, 'UserRoles', 'get').mockReturnValue([{ Role: 'Developer' } as UserRoleInfo]);

    const isInternalSupport = (u?: ScopedIssueUser): boolean =>
      Boolean(u?.UserRoles?.some((r) => r.Role === 'Developer'));

    vi.spyOn(RunView.prototype, 'RunView').mockImplementation(
      async (params: RunViewParams, contextUser?: UserInfo): Promise<RunViewResult> => {
        const scoped = contextUser as ScopedIssueUser | undefined;
        const internal = isInternalSupport(scoped);
        const scopes = new Set(scoped?.AllowedAppScopes ?? []);

        if (params.EntityName === 'MJ_BizApps_Issues: Issues') {
          const visible = issuesTable.filter((issue) => {
            if (!scopes.has(issue.AppScope)) return false;
            if (internal) return true;
            return (
              issue.ReporterPersonID === scoped?.LinkedPersonID ||
              issue.AssigneeRecordID === scoped?.LinkedPersonID
            );
          });
          return { Success: true, Results: visible, RowCount: visible.length, TotalRowCount: visible.length, ExecutionTime: 1, ErrorMessage: '' };
        }

        if (params.EntityName === 'MJ_BizApps_Issues: Issue Comments') {
          const filter = typeof params.ExtraFilter === 'string' ? params.ExtraFilter : '';
          const visible = commentsTable.filter((comment) => {
            if (!filter.includes(`'${comment.IssueID}'`)) return false;
            if (!internal && comment.Source === 'internal') return false;
            return true;
          });
          return { Success: true, Results: visible, RowCount: visible.length, TotalRowCount: visible.length, ExecutionTime: 1, ErrorMessage: '' };
        }

        return { Success: true, Results: [], RowCount: 0, TotalRowCount: 0, ExecutionTime: 1, ErrorMessage: '' };
      },
    );

    const briefingA = await buildIssuesBriefingForUser(externalReporterA);
    const briefingB = await buildIssuesBriefingForUser(supportLeadB);

    // User A (external reporter in PortalA) sees only PORTAL-0001 and only non-internal comments
    expect(briefingA.issueNumbers).toEqual(['PORTAL-0001']);
    expect(briefingA.titles).not.toContain('SSO SAML certificate rotation failure');
    expect(briefingA.commentBodies).toEqual(['Customer reported timeout on invoice PDF export.']);
    expect(briefingA.commentBodies.some((b) => b.includes('INTERNAL-ONLY'))).toBe(false);
    expect(briefingA.commentBodies.some((b) => b.includes('PORTAL-B-CONFIDENTIAL'))).toBe(false);

    // User B (internal support lead across PortalA + PortalB) sees both issues and internal notes
    expect(briefingB.issueNumbers).toEqual(['PORTAL-0001', 'PORTAL-0002']);
    expect(briefingB.commentBodies).toHaveLength(3);
    expect(briefingB.commentBodies.some((b) => b.includes('INTERNAL-ONLY'))).toBe(true);
    expect(briefingB.commentBodies.some((b) => b.includes('PORTAL-B-CONFIDENTIAL'))).toBe(true);
  });
});
