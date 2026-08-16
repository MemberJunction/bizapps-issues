import { Component } from '@angular/core';
import { RegisterClassEx } from '@memberjunction/global';
import { BaseFormPanel } from '@memberjunction/ng-base-forms';
import type { mjBizAppsIssuesIssueEntity } from '@mj-biz-apps/issues-entities';

/**
 * IssueOverviewPanel — contributes the primary 'Overview' rail section to the Issues form.
 * Wrapped in <mj-collapsible-panel SectionKey="overview" SectionName="Overview">
 * with slot: 'before-fields', contributionKey: 'overview', sortKey: 100.
 */
@RegisterClassEx(BaseFormPanel, {
    key: 'form-panel:Issues:overview',
    metadata: {
        entity: 'MJ_BizApps_Issues: Issues',
        slot: 'before-fields',
        sortKey: 100,
        contributionKey: 'overview',
    },
})
@Component({
    standalone: false,
    selector: 'mji-issue-overview-panel',
    template: `
        <mj-collapsible-panel
            SectionKey="overview"
            SectionName="Overview">
            <mji-issue-overview
                [Record]="Record"
                [FormComponent]="FormComponent">
            </mji-issue-overview>
        </mj-collapsible-panel>
    `,
})
export class IssueOverviewPanel extends BaseFormPanel<mjBizAppsIssuesIssueEntity> {}
