import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

// MemberJunction Imports
import { BaseFormsModule } from '@memberjunction/ng-base-forms';
import { LinkDirectivesModule } from '@memberjunction/ng-link-directives';

// Custom form components + the ReportIssueComponent are declared here in Phase 5.

@NgModule({
  declarations: [],
  imports: [
    CommonModule,
    FormsModule,
    BaseFormsModule,
    LinkDirectivesModule
  ],
  exports: []
})
export class CustomFormsModule { }
