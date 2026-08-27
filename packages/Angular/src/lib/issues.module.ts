import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

// Standalone components
import { IssueKanbanComponent } from './components/issue-kanban/issue-kanban.component';
import { IssueListComponent } from './components/issue-list/issue-list.component';
import { IssueDetailPanelComponent } from './components/issue-detail-panel/issue-detail-panel.component';
import { IssueEditPanelComponent } from './components/issue-edit-panel/issue-edit-panel.component';
import { ReportIssueComponent } from './components/report-issue/report-issue.component';
import { IssueOverviewComponent } from './components/issue-overview/issue-overview.component';

// Dashboard Pages
import { IssuesDashboardPageComponent } from './pages/issues-dashboard.page';
import { MyIssuesPageComponent } from './pages/my-issues.page';
import { IssueTriagePageComponent } from './pages/issue-triage.page';
import { IssueTypesPageComponent } from './pages/issue-types.page';

// Section Resources (DriverClasses)
import {
    IssuesSectionResource,
    MyIssuesSectionResource,
    IssueTriageSectionResource,
    IssueTypesSectionResource,
    LoadIssuesSectionResources,
} from './sections/issues-sections.component';

@NgModule({
    imports: [
        CommonModule,
        FormsModule,
        // Standalone components
        IssueKanbanComponent,
        IssueListComponent,
        IssueDetailPanelComponent,
        IssueEditPanelComponent,
        ReportIssueComponent,
        IssueOverviewComponent,
        IssuesDashboardPageComponent,
        MyIssuesPageComponent,
        IssueTriagePageComponent,
        IssueTypesPageComponent,
        IssuesSectionResource,
        MyIssuesSectionResource,
        IssueTriageSectionResource,
        IssueTypesSectionResource,
    ],
    exports: [
        IssueKanbanComponent,
        IssueListComponent,
        IssueDetailPanelComponent,
        IssueEditPanelComponent,
        ReportIssueComponent,
        IssueOverviewComponent,
        IssuesDashboardPageComponent,
        MyIssuesPageComponent,
        IssueTriagePageComponent,
        IssueTypesPageComponent,
        IssuesSectionResource,
        MyIssuesSectionResource,
        IssueTriageSectionResource,
        IssueTypesSectionResource,
    ],
})
export class IssuesModule {}

export { LoadIssuesSectionResources };
