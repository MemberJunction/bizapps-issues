/**
 * BizApps Issues Angular Bootstrap
 *
 * Client-side bootstrap package for the BizApps Issues Open App. Imports all
 * entity classes and form components so @RegisterClass decorators fire and
 * components are available to MJ's class factory.
 */

// Import entity package to trigger @RegisterClass decorators for entity subclasses
import '@mj-biz-apps/issues-entities';

// Import generated form components (triggers @RegisterClass for form components)
import './lib/generated/generated-forms.module';

// Import custom form components (must come AFTER generated to override via @RegisterClass priority)
import './lib/custom/custom-forms.module';

// Import class registrations manifest
import { CLASS_REGISTRATIONS } from './lib/generated/class-registrations-manifest';

// Re-export for consumers
export { CLASS_REGISTRATIONS } from './lib/generated/class-registrations-manifest';
export { GeneratedFormsModule } from './lib/generated/generated-forms.module';
export { CustomFormsModule } from './lib/custom/custom-forms.module';

// Reusable UI components
export { ReportIssueComponent } from './lib/components/report-issue/report-issue.component';

/**
 * Bootstrap function called during MJExplorer initialization.
 * Static imports above handle all registration.
 */
export function LoadBizAppsIssuesClient(): void {
  // Static imports ensure all classes are registered.
  void CLASS_REGISTRATIONS;
}
