import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

// MemberJunction Imports
import { BaseFormsModule } from '@memberjunction/ng-base-forms';
import { LinkDirectivesModule } from '@memberjunction/ng-link-directives';

// Standalone feature components (imported, not declared)
import { ReportIssueComponent } from '../components/report-issue/report-issue.component';

@NgModule({
  declarations: [],
  imports: [
    CommonModule,
    FormsModule,
    BaseFormsModule,
    LinkDirectivesModule,
    // Standalone components used across the app
    ReportIssueComponent
  ],
  exports: [
    ReportIssueComponent
  ]
})
export class CustomFormsModule { }
