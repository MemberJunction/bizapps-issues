import { Component, Input, Output, EventEmitter, OnInit, OnChanges, SimpleChanges, ChangeDetectorRef, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RunView, CompositeKey, Metadata } from '@memberjunction/core';
import { NavigationService } from '@memberjunction/ng-shared';
import type { IssueCardItem } from '../issue-kanban/issue-kanban.component';
import type { mjBizAppsIssuesIssueStatusEntity, mjBizAppsIssuesIssueCommentEntity } from '@mj-biz-apps/issues-entities';

interface IssueCommentView {
    ID: string;
    Comment: string;
    User: string;
    CreatedAt: Date;
}

const ISSUE_DETAIL_CSS = `
.mji-drawer-scrim {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    backdrop-filter: blur(2px);
    z-index: 999;
}

.mji-drawer {
    position: fixed;
    top: 0;
    right: 0;
    bottom: 0;
    width: 480px;
    max-width: 90vw;
    background: var(--mj-bg-surface, #111a2e);
    border-left: 1px solid var(--mj-border-default, #223254);
    display: flex;
    flex-direction: column;
    z-index: 1000;
    box-shadow: -8px 0 24px rgba(0, 0, 0, 0.4);
    animation: mjiSlideIn 0.2s ease;
}

.mji-drawer-header {
    padding: 16px 20px;
    border-bottom: 1px solid var(--mj-border-default, #223254);
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: var(--mj-bg-surface-card, #141f36);
}

.mji-drawer-title-row {
    display: flex;
    align-items: center;
    gap: 10px;
}

.mji-drawer-body {
    padding: 20px;
    overflow-y: auto;
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 20px;
    scrollbar-width: thin;
}

.mji-section-title {
    font-size: 11px;
    font-weight: 700;
    color: var(--mj-text-muted, #64748b);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin-bottom: 8px;
}

.mji-detail-card {
    background: var(--mj-bg-surface-card, #141f36);
    border: 1px solid var(--mj-border-default, #223254);
    border-radius: 8px;
    padding: 14px;
}

.mji-grid-stats {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
}

.mji-stat-box {
    display: flex;
    flex-direction: column;
    gap: 2px;
}

.mji-stat-label {
    font-size: 10.5px;
    color: var(--mj-text-muted, #64748b);
}

.mji-stat-val {
    font-size: 13px;
    font-weight: 600;
    color: var(--mj-text-primary, #f8fafc);
}

.mji-comments-list {
    display: flex;
    flex-direction: column;
    gap: 10px;
}

.mji-comment-bubble {
    background: var(--mj-bg-surface-card, #141f36);
    border: 1px solid var(--mj-border-default, #223254);
    border-radius: 8px;
    padding: 10px 12px;
}

.mji-comment-meta {
    display: flex;
    align-items: center;
    justify-content: space-between;
    font-size: 11px;
    color: var(--mj-text-muted, #64748b);
    margin-bottom: 4px;
}

.mji-comment-text {
    font-size: 12px;
    color: var(--mj-text-secondary, #94a3b8);
    line-height: 1.4;
    margin: 0;
}

.mji-composer {
    display: flex;
    gap: 8px;
}

.mji-input {
    flex: 1;
    background: var(--mj-bg-surface-sunken, #090e1a);
    border: 1px solid var(--mj-border-default, #223254);
    border-radius: 6px;
    color: var(--mj-text-primary, #f8fafc);
    padding: 8px 10px;
    font-size: 12px;
}

.mji-input:focus {
    outline: none;
    border-color: var(--mj-brand-primary, #38bdf8);
}

.mji-btn {
    padding: 6px 12px;
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

.mji-btn--secondary {
    background: var(--mj-bg-surface-elevated, #1a2744);
    border: 1px solid var(--mj-border-default, #223254);
    color: var(--mj-text-primary, #f8fafc);
}

.mji-btn--secondary:hover {
    background: var(--mj-border-default, #223254);
}

.mji-close-btn {
    background: none;
    border: none;
    color: var(--mj-text-muted, #64748b);
    font-size: 16px;
    cursor: pointer;
}

.mji-close-btn:hover {
    color: var(--mj-text-primary, #f8fafc);
}

@keyframes mjiSlideIn {
    from { transform: translateX(100%); }
    to { transform: translateX(0); }
}
`;

@Component({
    selector: 'bizapps-issue-detail-panel',
    standalone: true,
    imports: [CommonModule, FormsModule],
    template: `
        <div class="mji-drawer-scrim" (click)="Close.emit()"></div>
        <div class="mji-drawer">
            <div class="mji-drawer-header">
                <div class="mji-drawer-title-row">
                    <span style="font-family: 'JetBrains Mono'; font-weight: 700; color: var(--mj-brand-primary);">
                        {{ Issue?.IssueNumber }}
                    </span>
                    <button class="mji-btn mji-btn--secondary" (click)="OpenFullRecord()" type="button">
                        <i class="fa-solid fa-arrow-up-right-from-square"></i> Open Full Form
                    </button>
                </div>
                <button class="mji-close-btn" (click)="Close.emit()" type="button">
                    <i class="fa-solid fa-xmark"></i>
                </button>
            </div>

            <div class="mji-drawer-body">
                <div>
                    <h2 style="font-size: 16px; font-weight: 700; color: var(--mj-text-primary); margin: 0 0 6px 0;">
                        {{ Issue?.Title }}
                    </h2>
                    <p style="font-size: 12.5px; color: var(--mj-text-secondary); line-height: 1.45; margin: 0;">
                        {{ Issue?.Description || 'No description provided.' }}
                    </p>
                </div>

                <div class="mji-detail-card">
                    <div class="mji-section-title">Issue Attributes</div>
                    <div class="mji-grid-stats">
                        <div class="mji-stat-box">
                            <span class="mji-stat-label">Severity</span>
                            <span class="mji-stat-val">{{ Issue?.Severity }}</span>
                        </div>
                        <div class="mji-stat-box">
                            <span class="mji-stat-label">Priority</span>
                            <span class="mji-stat-val">{{ Issue?.Priority }}</span>
                        </div>
                        <div class="mji-stat-box">
                            <span class="mji-stat-label">Status</span>
                            <span class="mji-stat-val">{{ Issue?.StatusName || 'Reported' }}</span>
                        </div>
                        <div class="mji-stat-box">
                            <span class="mji-stat-label">Application Scope</span>
                            <span class="mji-stat-val">{{ Issue?.AppScope || 'Global' }}</span>
                        </div>
                        <div class="mji-stat-box">
                            <span class="mji-stat-label">Reporter</span>
                            <span class="mji-stat-val">{{ Issue?.ReporterEmail || 'Internal' }}</span>
                        </div>
                        <div class="mji-stat-box">
                            <span class="mji-stat-label">Created At</span>
                            <span class="mji-stat-val">{{ CreatedDateLabel }}</span>
                        </div>
                    </div>
                </div>

                <div>
                    <div class="mji-section-title">Discussion &amp; Notes ({{ Comments.length }})</div>
                    <div class="mji-comments-list">
                        @if (Comments.length > 0) {
                            @for (c of Comments; track c.ID) {
                                <div class="mji-comment-bubble">
                                    <div class="mji-comment-meta">
                                        <strong>{{ c.User }}</strong>
                                        <span>{{ FormatTime(c.CreatedAt) }}</span>
                                    </div>
                                    <p class="mji-comment-text">{{ c.Comment }}</p>
                                </div>
                            }
                        } @else {
                            <div style="font-size: 12px; color: var(--mj-text-muted); font-style: italic;">
                                No comments posted yet. Add a note below.
                            </div>
                        }

                        <div class="mji-composer">
                            <input
                                class="mji-input"
                                [(ngModel)]="NewComment"
                                (keyup.enter)="PostComment()"
                                placeholder="Add a comment or triage note..." />
                            <button
                                class="mji-btn mji-btn--primary"
                                [disabled]="!NewComment.trim() || IsSavingComment"
                                (click)="PostComment()"
                                type="button">
                                Send
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    `,
    styles: [ISSUE_DETAIL_CSS]
})
export class IssueDetailPanelComponent implements OnInit, OnChanges {
    @Input() public Issue: IssueCardItem | null = null;
    @Output() public Close = new EventEmitter<void>();

    private cdr = inject(ChangeDetectorRef);
    private navService = inject(NavigationService, { optional: true });

    public Comments: IssueCommentView[] = [];
    public NewComment = '';
    public IsSavingComment = false;

    public get CreatedDateLabel(): string {
        if (!this.Issue?.CreatedAt) return '—';
        return new Date(this.Issue.CreatedAt).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    }

    public FormatTime(d: Date): string {
        if (!d) return '';
        return new Date(d).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
    }

    public ngOnInit(): void {
        this.LoadComments();
    }

    public ngOnChanges(changes: SimpleChanges): void {
        if (changes['Issue'] && !changes['Issue'].firstChange) {
            this.LoadComments();
        }
    }

    public async LoadComments(): Promise<void> {
        if (!this.Issue?.ID) return;
        try {
            const rv = new RunView();
            const res = await rv.RunView<Record<string, unknown>>({
                EntityName: 'MJ_BizApps_Issues: Issue Comments',
                ExtraFilter: `IssueID = '${this.Issue.ID}'`,
                OrderBy: '__mj_CreatedAt ASC',
                ResultType: 'simple'
            });

            if (res?.Success && res.Results) {
                this.Comments = res.Results.map(c => ({
                    ID: String(c['ID'] || ''),
                    Comment: String(c['Comment'] || c['Body'] || ''),
                    User: String(c['User'] || c['AuthorEmail'] || 'Team Member'),
                    CreatedAt: new Date(String(c['__mj_CreatedAt'] || Date.now()))
                }));
                this.cdr.detectChanges();
            }
        } catch (e) {
            console.warn('[IssueDetail] Error loading comments:', e);
        }
    }

    public async PostComment(): Promise<void> {
        if (!this.NewComment.trim() || !this.Issue?.ID || this.IsSavingComment) return;
        this.IsSavingComment = true;

        try {
            const md = new Metadata();
            const commentEntity = await md.GetEntityObject<mjBizAppsIssuesIssueCommentEntity>('MJ_BizApps_Issues: Issue Comments');
            if (commentEntity) {
                commentEntity.IssueID = this.Issue.ID;
                commentEntity.Body = this.NewComment.trim();
                commentEntity.Source = 'internal';
                // Attribute the comment to its author — without this every comment is
                // saved anonymous and rendered as "Team Member", leaving no reliable
                // authorship on what becomes a customer-facing audit trail.
                commentEntity.AuthorEmail = md.CurrentUser?.Email ?? null;
                const success = await commentEntity.Save();
                if (success) {
                    this.NewComment = '';
                    await this.LoadComments();
                }
            }
        } catch (e) {
            console.error('[IssueDetail] Failed to save comment:', e);
        } finally {
            this.IsSavingComment = false;
            this.cdr.detectChanges();
        }
    }

    public OpenFullRecord(): void {
        if (!this.Issue?.ID) return;
        const pk = CompositeKey.FromID(this.Issue.ID);
        if (this.navService) {
            this.navService.OpenEntityRecord('MJ_BizApps_Issues: Issues', pk);
            this.Close.emit();
        }
    }
}
