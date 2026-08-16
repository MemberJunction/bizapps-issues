/**
 * BizApps Issues Angular Bootstrap
 *
 * Client-side bootstrap package for the BizApps Issues Open App. Imports all
 * entity classes, forms, dashboards, and section resources so @RegisterClass
 * decorators fire and components are available to MJ's class factory.
 */

// Import entity package to trigger @RegisterClass decorators for entity subclasses
import '@mj-biz-apps/issues-entities';

// Import generated form components (triggers @RegisterClass for form components)
import './lib/generated/generated-forms.module';

// Import custom form components (must come AFTER generated to override via @RegisterClass priority)
import './lib/custom/custom-forms.module';

// Import issues module and section resources
import './lib/issues.module';
import { LoadIssuesSectionResources } from './lib/sections/issues-sections.component';

// Import class registrations manifest
import { CLASS_REGISTRATIONS } from './lib/generated/class-registrations-manifest';

// Re-export for consumers
export { CLASS_REGISTRATIONS } from './lib/generated/class-registrations-manifest';
export { GeneratedFormsModule } from './lib/generated/generated-forms.module';
export { CustomFormsModule } from './lib/custom/custom-forms.module';
export { IssuesModule } from './lib/issues.module';

// Reusable UI components
export { ReportIssueComponent } from './lib/components/report-issue/report-issue.component';
export { IssueOverviewComponent } from './lib/components/issue-overview/issue-overview.component';
export { IssueKanbanComponent } from './lib/components/issue-kanban/issue-kanban.component';
export { IssueListComponent } from './lib/components/issue-list/issue-list.component';
export { IssueDetailPanelComponent } from './lib/components/issue-detail-panel/issue-detail-panel.component';
export { IssueEditPanelComponent } from './lib/components/issue-edit-panel/issue-edit-panel.component';

// Form Panels
export { IssueHeroHeaderPanel } from './lib/custom/form-panels/issue-hero-header.panel';
export { IssueOverviewPanel } from './lib/custom/form-panels/issue-overview.panel';

// Dashboard Pages
export { IssuesDashboardPageComponent } from './lib/pages/issues-dashboard.page';
export { MyIssuesPageComponent } from './lib/pages/my-issues.page';
export { IssueTriagePageComponent } from './lib/pages/issue-triage.page';
export { IssueTypesPageComponent } from './lib/pages/issue-types.page';

// Section Resources (DriverClasses)
export {
    IssuesSectionResource,
    MyIssuesSectionResource,
    IssueTriageSectionResource,
    IssueTypesSectionResource,
    LoadIssuesSectionResources,
} from './lib/sections/issues-sections.component';

/**
 * Bootstrap function called during MJExplorer initialization.
 * Static imports above handle all registration.
 */
export function LoadBizAppsIssuesClient(): void {
  // Static imports ensure all classes are registered.
  LoadIssuesSectionResources();
  void CLASS_REGISTRATIONS;
}
