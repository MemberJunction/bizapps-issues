import {
  Component,
  Input,
  Output,
  EventEmitter,
  inject,
  ChangeDetectorRef,
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

import { Metadata, RunView, LogError } from '@memberjunction/core';
import {
  MJDialogComponent,
  MJDialogTitlebarComponent,
  MJDialogActionsComponent,
  MJDropdownComponent,
  MJButtonDirective,
} from '@memberjunction/ng-ui-components';
// LoadingComponent (<mj-loading>) is declared by SharedGenericModule (non-standalone),
// so we import the module rather than the component into this standalone component.
import { SharedGenericModule } from '@memberjunction/ng-shared-generic';

import {
  mjBizAppsIssuesIssueEntity,
  mjBizAppsIssuesIssueTypeEntity,
  mjBizAppsIssuesIssueStatusEntity,
} from '@mj-biz-apps/issues-entities';

/** Severity / Priority union (mirrors the Issue entity). */
type IssuePriority = 'Low' | 'Medium' | 'High' | 'Critical';

/**
 * ReportIssueComponent — a self-contained "Report an Issue / Submit Feedback" dialog.
 *
 * This is the entry point the Shell Extension surfaces (avatar/context menu). It is a thin
 * client-side UI: it creates an Issue record directly via the MJ entity API (which routes
 * through GraphQLDataProvider in the browser), defaulting status to the configured default
 * status and priority to the chosen type's DefaultPriority. Server-side IssueType action hooks
 * fire automatically when the record is saved.
 *
 * It can be opened standalone, or "about" a specific record by setting SourceEntityID +
 * SourceRecordID (e.g. "report an issue about THIS dashboard"). AppScope tags which product the
 * issue belongs to.
 *
 * Usage:
 * ```html
 * <mj-report-issue [(Visible)]="showReport" AppScope="MJC"
 *                  (Submitted)="onIssueSubmitted($event)"></mj-report-issue>
 * ```
 */
@Component({
  selector: 'mj-report-issue',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    MJDialogComponent,
    MJDialogTitlebarComponent,
    MJDialogActionsComponent,
    MJDropdownComponent,
    MJButtonDirective,
    SharedGenericModule,
  ],
  templateUrl: './report-issue.component.html',
  styleUrls: ['./report-issue.component.css'],
})
export class ReportIssueComponent {
  private cdr = inject(ChangeDetectorRef);

  // ----------------------------------------------------------------
  // Inputs / Outputs
  // ----------------------------------------------------------------

  private _visible = false;
  /** Controls dialog visibility. On open, loads reference data (once). */
  @Input()
  set Visible(value: boolean) {
    const wasVisible = this._visible;
    this._visible = value;
    if (value && !wasVisible) {
      void this.onOpen();
    }
  }
  get Visible(): boolean {
    return this._visible;
  }
  @Output() VisibleChange = new EventEmitter<boolean>();

  /** Optional polymorphic source: the entity this issue is about. */
  @Input() SourceEntityID: string | null = null;
  /** Optional polymorphic source: the record ID this issue is about. */
  @Input() SourceRecordID: string | null = null;
  /** Optional app/product scope tag stamped onto the issue. */
  @Input() AppScope: string | null = null;
  /** Optional reporter email for anonymous/external reporters. */
  @Input() ReporterEmail: string | null = null;

  /** Emits the created Issue after a successful submit. */
  @Output() Submitted = new EventEmitter<mjBizAppsIssuesIssueEntity>();
  /** Emits when the dialog is cancelled/closed without submitting. */
  @Output() Cancelled = new EventEmitter<void>();

  // ----------------------------------------------------------------
  // State
  // ----------------------------------------------------------------

  public IsLoading = false;
  public IsSubmitting = false;
  public ErrorMessage: string | null = null;

  public IssueTypes: mjBizAppsIssuesIssueTypeEntity[] = [];

  // Form model
  public Title = '';
  public Description = '';
  public SelectedTypeID: string | null = null;
  public Severity: IssuePriority = 'Medium';

  public readonly SeverityOptions: IssuePriority[] = ['Low', 'Medium', 'High', 'Critical'];

  private defaultStatusID: string | null = null;
  private referenceLoaded = false;

  // ----------------------------------------------------------------
  // Lifecycle
  // ----------------------------------------------------------------

  /** Loads issue types + the default status the first time the dialog opens. */
  private async onOpen(): Promise<void> {
    this.resetForm();
    if (this.referenceLoaded) {
      return;
    }
    this.IsLoading = true;
    this.cdr.detectChanges();
    try {
      await this.loadReferenceData();
      this.referenceLoaded = true;
    } catch (err) {
      this.ErrorMessage = 'Failed to load issue options. Please try again.';
      LogError(`ReportIssueComponent.onOpen: ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      this.IsLoading = false;
      this.cdr.detectChanges();
    }
  }

  private async loadReferenceData(): Promise<void> {
    const rv = new RunView();
    const [typesResult, statusesResult] = await rv.RunViews([
      {
        EntityName: 'MJ_BizApps_Issues: Issue Types',
        ExtraFilter: 'IsActive = 1',
        OrderBy: 'Name',
        ResultType: 'entity_object',
      },
      {
        EntityName: 'MJ_BizApps_Issues: Issue Status',
        ExtraFilter: 'IsDefault = 1',
        ResultType: 'entity_object',
      },
    ]);

    if (typesResult.Success) {
      this.IssueTypes = typesResult.Results as mjBizAppsIssuesIssueTypeEntity[];
      this.SelectedTypeID = this.IssueTypes[0]?.ID ?? null;
    } else {
      LogError(`ReportIssueComponent: failed to load Issue Types: ${typesResult.ErrorMessage}`);
    }

    if (statusesResult.Success) {
      const statuses = statusesResult.Results as mjBizAppsIssuesIssueStatusEntity[];
      this.defaultStatusID = statuses[0]?.ID ?? null;
    } else {
      LogError(`ReportIssueComponent: failed to load default status: ${statusesResult.ErrorMessage}`);
    }
  }

  // ----------------------------------------------------------------
  // Actions
  // ----------------------------------------------------------------

  /** Whether the form is valid enough to submit. */
  public get CanSubmit(): boolean {
    return !this.IsSubmitting && this.Title.trim().length > 0 && !!this.SelectedTypeID && !!this.defaultStatusID;
  }

  /** Creates the Issue record and emits Submitted on success. */
  public async Submit(): Promise<void> {
    if (!this.CanSubmit) {
      return;
    }
    this.IsSubmitting = true;
    this.ErrorMessage = null;
    this.cdr.detectChanges();

    try {
      const md = new Metadata();
      const issue = await md.GetEntityObject<mjBizAppsIssuesIssueEntity>('MJ_BizApps_Issues: Issues');
      issue.NewRecord();
      issue.Title = this.Title.trim();
      issue.Description = this.Description.trim() || null;
      issue.IssueTypeID = this.SelectedTypeID!;
      issue.StatusID = this.defaultStatusID!;
      issue.Severity = this.Severity;
      issue.Priority = this.selectedTypeDefaultPriority();
      issue.ReporterEmail = this.ReporterEmail;
      issue.SourceEntityID = this.SourceEntityID;
      issue.SourceRecordID = this.SourceRecordID;
      issue.AppScope = this.AppScope;

      const saved = await issue.Save();
      if (!saved) {
        this.ErrorMessage = issue.LatestResult?.CompleteMessage ?? 'Failed to submit the issue.';
        LogError(`ReportIssueComponent.Submit: ${this.ErrorMessage}`);
        return;
      }

      this.Submitted.emit(issue);
      this.close();
    } catch (err) {
      this.ErrorMessage = 'An unexpected error occurred while submitting.';
      LogError(`ReportIssueComponent.Submit: ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      this.IsSubmitting = false;
      this.cdr.detectChanges();
    }
  }

  /** Cancels the dialog without submitting. */
  public Cancel(): void {
    this.Cancelled.emit();
    this.close();
  }

  /** Handles the dialog's own Close event (escape/backdrop/X). */
  public OnDialogClose(): void {
    this.Cancel();
  }

  // ----------------------------------------------------------------
  // Helpers
  // ----------------------------------------------------------------

  /** The DefaultPriority of the currently-selected type, or 'Medium'. */
  private selectedTypeDefaultPriority(): IssuePriority {
    const type = this.IssueTypes.find((t) => t.ID === this.SelectedTypeID);
    return (type?.DefaultPriority as IssuePriority) ?? 'Medium';
  }

  private resetForm(): void {
    this.Title = '';
    this.Description = '';
    this.Severity = 'Medium';
    this.ErrorMessage = null;
    this.SelectedTypeID = this.IssueTypes[0]?.ID ?? null;
  }

  private close(): void {
    this._visible = false;
    this.VisibleChange.emit(false);
    this.cdr.detectChanges();
  }
}
