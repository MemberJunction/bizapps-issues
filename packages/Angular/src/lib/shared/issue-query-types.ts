import type {
    mjBizAppsIssuesIssueEntity,
    mjBizAppsIssuesIssueCommentEntity,
} from '@mj-biz-apps/issues-entities';
import type { IssueCardItem } from '../components/issue-kanban/issue-kanban.component';

/** Explicit column projection for `ResultType: 'simple'` queries on `MJ_BizApps_Issues: Issues`. */
export const ISSUE_LIST_FIELDS = [
    'ID',
    'IssueNumber',
    'Title',
    'Description',
    'Severity',
    'Priority',
    'StatusID',
    'Status',
    'ReporterEmail',
    'AppScope',
    '__mj_CreatedAt',
    'ResolvedAt',
] as const;

export interface IssueSimpleRow {
    ID: string;
    IssueNumber: string | null;
    Title: string | null;
    Description: string | null;
    Severity: mjBizAppsIssuesIssueEntity['Severity'] | null;
    Priority: mjBizAppsIssuesIssueEntity['Priority'] | null;
    StatusID: string | null;
    Status: string | null;
    ReporterEmail: string | null;
    AppScope: string | null;
    __mj_CreatedAt: Date | string | null;
    ResolvedAt: Date | string | null;
}

/** Explicit column projection for `ResultType: 'simple'` queries on `MJ_BizApps_Issues: Issue Comments`. */
export const ISSUE_COMMENT_FIELDS = [
    'ID',
    'Body',
    'AuthorPerson',
    'AuthorEmail',
    '__mj_CreatedAt',
] as const;

export interface IssueCommentSimpleRow {
    ID: string;
    Body: mjBizAppsIssuesIssueCommentEntity['Body'] | null;
    AuthorPerson: mjBizAppsIssuesIssueCommentEntity['AuthorPerson'] | null;
    AuthorEmail: mjBizAppsIssuesIssueCommentEntity['AuthorEmail'] | null;
    __mj_CreatedAt: Date | string | null;
}

export function MapIssueSimpleRowToCardItem(row: IssueSimpleRow): IssueCardItem {
    return {
        ID: row.ID || '',
        IssueNumber: row.IssueNumber || 'ISSUE',
        Title: row.Title || 'Untitled Issue',
        Description: row.Description || '',
        Severity: row.Severity || 'Medium',
        Priority: row.Priority || 'Medium',
        StatusID: row.StatusID || '',
        StatusName: row.Status || 'Reported',
        ReporterEmail: row.ReporterEmail || '',
        AppScope: row.AppScope || 'Explorer',
        CreatedAt: new Date(row.__mj_CreatedAt ?? Date.now()),
        ResolvedAt: row.ResolvedAt ? new Date(row.ResolvedAt) : null,
    };
}
