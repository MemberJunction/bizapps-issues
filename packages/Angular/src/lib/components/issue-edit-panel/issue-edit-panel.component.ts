import { Component, Input, Output, EventEmitter, OnInit, ChangeDetectorRef, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Metadata } from '@memberjunction/core';
import type { mjBizAppsIssuesIssueStatusEntity, mjBizAppsIssuesIssueTypeEntity, mjBizAppsIssuesIssueEntity } from '@mj-biz-apps/issues-entities';

const ISSUE_EDIT_CSS = `
.mji-modal-scrim {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.6);
    backdrop-filter: blur(4px);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
}

.mji-modal {
    width: 540px;
    max-width: 95vw;
    background: var(--mj-bg-surface, #111a2e);
    border: 1px solid var(--mj-border-default, #223254);
    border-radius: var(--mj-radius-lg, 14px);
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.5);
    display: flex;
    flex-direction: column;
    overflow: hidden;
    animation: mjiModalPop 0.2s ease;
}

.mji-modal-header {
    padding: 16px 20px;
    border-bottom: 1px solid var(--mj-border-default, #223254);
    background: var(--mj-bg-surface-card, #141f36);
    display: flex;
    align-items: center;
    justify-content: space-between;
}

.mji-modal-title {
    font-size: 15px;
    font-weight: 700;
    color: var(--mj-text-primary, #f8fafc);
    margin: 0;
}

.mji-modal-body {
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 14px;
    max-height: 75vh;
    overflow-y: auto;
}

.mji-field {
    display: flex;
    flex-direction: column;
    gap: 6px;
}

.mji-label {
    font-size: 11.5px;
    font-weight: 600;
    color: var(--mj-text-secondary, #94a3b8);
}

.mji-input, .mji-select, .mji-textarea {
    background: var(--mj-bg-surface-sunken, #090e1a);
    border: 1px solid var(--mj-border-default, #223254);
    border-radius: 6px;
    color: var(--mj-text-primary, #f8fafc);
    padding: 8px 10px;
    font-size: 12.5px;
}

.mji-textarea {
    resize: vertical;
    min-height: 80px;
}

.mji-input:focus, .mji-select:focus, .mji-textarea:focus {
    outline: none;
    border-color: var(--mj-brand-primary, #38bdf8);
}

.mji-row-2 {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
}

.mji-modal-footer {
    padding: 14px 20px;
    border-top: 1px solid var(--mj-border-default, #223254);
    background: var(--mj-bg-surface-card, #141f36);
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 10px;
}

.mji-btn {
    padding: 8px 16px;
    border-radius: 6px;
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    border: none;
    transition: all 0.15s ease;
}

.mji-btn--primary {
    background: var(--mj-brand-primary, #38bdf8);
    color: #090e1a;
}

.mji-btn--primary:disabled {
    opacity: 0.5;
    cursor: not-allowed;
}

.mji-btn--secondary {
    background: var(--mj-bg-surface-elevated, #1a2744);
    border: 1px solid var(--mj-border-default, #223254);
    color: var(--mj-text-primary, #f8fafc);
}

@keyframes mjiModalPop {
    from { opacity: 0; transform: scale(0.96); }
    to { opacity: 1; transform: scale(1); }
}
`;

@Component({
    selector: 'bizapps-issue-edit-panel',
    standalone: true,
    imports: [CommonModule, FormsModule],
    template: `
        <div class="mji-modal-scrim">
            <div class="mji-modal">
                <div class="mji-modal-header">
                    <h3 class="mji-modal-title">
                        <i class="fa-solid fa-bug" style="color: var(--mj-brand-primary); margin-right: 6px;"></i>
                        Report New Issue
                    </h3>
                    <button style="background:none; border:none; color:var(--mj-text-muted); cursor:pointer; font-size:16px;" (click)="Cancel.emit()" type="button">
                        <i class="fa-solid fa-xmark"></i>
                    </button>
                </div>

                <div class="mji-modal-body">
                    <div class="mji-field">
                        <label class="mji-label">Issue Title *</label>
                        <input class="mji-input" [(ngModel)]="Title" placeholder="e.g. Broken link on checkout confirmation" />
                    </div>

                    <div class="mji-field">
                        <label class="mji-label">Detailed Description</label>
                        <textarea class="mji-textarea" [(ngModel)]="Description" placeholder="Steps to reproduce, expected vs actual behavior..."></textarea>
                    </div>

                    <div class="mji-row-2">
                        <div class="mji-field">
                            <label class="mji-label">Severity</label>
                            <select class="mji-select" [(ngModel)]="Severity">
                                <option value="Low">Low</option>
                                <option value="Medium">Medium</option>
                                <option value="High">High</option>
                                <option value="Critical">Critical</option>
                            </select>
                        </div>

                        <div class="mji-field">
                            <label class="mji-label">Priority</label>
                            <select class="mji-select" [(ngModel)]="Priority">
                                <option value="Low">Low</option>
                                <option value="Medium">Medium</option>
                                <option value="High">High</option>
                                <option value="Critical">Critical</option>
                            </select>
                        </div>
                    </div>

                    <div class="mji-row-2">
                        <div class="mji-field">
                            <label class="mji-label">Issue Type</label>
                            <select class="mji-select" [(ngModel)]="IssueTypeID">
                                @for (t of IssueTypes; track t.ID) {
                                    <option [value]="t.ID">{{ t.Name }}</option>
                                }
                            </select>
                        </div>

                        <div class="mji-field">
                            <label class="mji-label">Application Scope</label>
                            <input class="mji-input" [(ngModel)]="AppScope" placeholder="e.g. Explorer, Orders, MJC" />
                        </div>
                    </div>

                    <div class="mji-field">
                        <label class="mji-label">Reporter Email</label>
                        <input class="mji-input" [(ngModel)]="ReporterEmail" placeholder="user@company.com" />
                    </div>
                </div>

                <div class="mji-modal-footer">
                    <button class="mji-btn mji-btn--secondary" (click)="Cancel.emit()" type="button">Cancel</button>
                    <button class="mji-btn mji-btn--primary" [disabled]="!Title.trim() || IsSaving" (click)="SaveIssue()" type="button">
                        {{ IsSaving ? 'Saving...' : 'Create Issue' }}
                    </button>
                </div>
            </div>
        </div>
    `,
    styles: [ISSUE_EDIT_CSS]
})
export class IssueEditPanelComponent implements OnInit {
    @Input() public IssueTypes: mjBizAppsIssuesIssueTypeEntity[] = [];
    @Input() public Statuses: mjBizAppsIssuesIssueStatusEntity[] = [];
    @Output() public Saved = new EventEmitter<void>();
    @Output() public Cancel = new EventEmitter<void>();

    public Title = '';
    public Description = '';
    public Severity: 'Critical' | 'High' | 'Low' | 'Medium' = 'Medium';
    public Priority: 'Critical' | 'High' | 'Low' | 'Medium' = 'Medium';
    public IssueTypeID = '';
    public AppScope = 'Explorer';
    public ReporterEmail = '';
    public IsSaving = false;

    private cdr = inject(ChangeDetectorRef);

    public ngOnInit(): void {
        if (this.IssueTypes.length > 0) {
            this.IssueTypeID = this.IssueTypes[0].ID;
        }
    }

    public async SaveIssue(): Promise<void> {
        if (!this.Title.trim() || this.IsSaving) return;
        this.IsSaving = true;

        try {
            const md = new Metadata();
            const issueEntity = await md.GetEntityObject<mjBizAppsIssuesIssueEntity>('MJ_BizApps_Issues: Issues');
            if (issueEntity) {
                issueEntity.Title = this.Title.trim();
                issueEntity.Description = this.Description.trim();
                issueEntity.Severity = this.Severity;
                issueEntity.Priority = this.Priority;
                if (this.IssueTypeID) issueEntity.IssueTypeID = this.IssueTypeID;
                if (this.Statuses.length > 0) issueEntity.StatusID = this.Statuses[0].ID;
                issueEntity.AppScope = this.AppScope;
                if (this.ReporterEmail) issueEntity.ReporterEmail = this.ReporterEmail.trim();

                const success = await issueEntity.Save();
                if (success) {
                    this.Saved.emit();
                }
            }
        } catch (e) {
            console.error('[IssueEdit] Failed to create issue:', e);
        } finally {
            this.IsSaving = false;
            this.cdr.detectChanges();
        }
    }
}
