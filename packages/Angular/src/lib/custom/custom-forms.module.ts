import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

// MemberJunction Imports
import { BaseFormsModule } from '@memberjunction/ng-base-forms';
import { LinkDirectivesModule } from '@memberjunction/ng-link-directives';

// Standalone feature components
import { ReportIssueComponent } from '../components/report-issue/report-issue.component';
import { IssueOverviewComponent } from '../components/issue-overview/issue-overview.component';

// Form panels
import { IssueHeroHeaderPanel } from './form-panels/issue-hero-header.panel';
import { IssueOverviewPanel } from './form-panels/issue-overview.panel';

const PANELS = [
  IssueHeroHeaderPanel,
  IssueOverviewPanel,
];

@NgModule({
  declarations: [...PANELS],
  imports: [
    CommonModule,
    FormsModule,
    BaseFormsModule,
    LinkDirectivesModule,
    ReportIssueComponent,
    IssueOverviewComponent,
  ],
  exports: [
    ...PANELS,
    ReportIssueComponent,
    IssueOverviewComponent,
  ]
})
export class CustomFormsModule { }
