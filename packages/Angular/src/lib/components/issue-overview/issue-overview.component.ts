import { Component, Input, OnInit, OnChanges, SimpleChanges, ChangeDetectorRef, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { CompositeKey, Metadata, RunView } from '@memberjunction/core';
import {
    MJCardGridComponent,
    MJCardComponent,
    MJCardToolsDirective,
    MJCardFooterDirective,
} from '@memberjunction/ng-ui-components';
import { NavigationService } from '@memberjunction/ng-shared';
import { BaseFormComponent } from '@memberjunction/ng-base-forms';
import type { mjBizAppsIssuesIssueEntity } from '@mj-biz-apps/issues-entities';

interface IssueCommentSummary {
    ID: string;
    Comment: string;
    CreatedAt: Date;
    User: string;
}

const ISSUE_OVERVIEW_CSS = `
.mji-overview {
    display: flex;
    flex-direction: column;
    gap: 16px;
    width: 100%;
}

.mji-chart-bars {
    height: 110px;
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    gap: 8px;
    padding: 10px 0 4px 0;
}

.mji-bar-col {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
    height: 100%;
    justify-content: flex-end;
}

.mji-bar-fill {
    width: 100%;
    max-width: 28px;
    min-height: 4px;
    border-radius: 4px 4px 0 0;
    background: linear-gradient(180deg, #38bdf8 0%, rgba(56, 189, 248, 0.3) 100%);
    transition: all 0.2s ease;
}

.mji-bar-fill--peak {
    background: linear-gradient(180deg, #10b981 0%, rgba(16, 185, 129, 0.3) 100%);
}

.mji-bar-lbl {
    font-size: 10.5px;
    font-weight: 600;
    color: var(--mj-text-muted, #64748b);
}

.mji-deck {
    display: flex;
    flex-direction: column;
    gap: 8px;
}

.mji-deck-item {
    background: var(--mj-bg-surface-sunken, #090e1a);
    border: 1px solid var(--mj-border-default, #223254);
    border-radius: 8px;
    padding: 8px 12px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 10px;
    cursor: pointer;
    transition: all 0.15s ease;
}

.mji-deck-item:hover {
    border-color: var(--mj-brand-primary, #38bdf8);
    background: var(--mj-bg-surface-elevated, #1a2744);
    transform: translateX(2px);
}

.mji-deck-item__left {
    display: flex;
    align-items: center;
    gap: 10px;
    min-width: 0;
}

.mji-deck-item__icon {
    width: 26px;
    height: 26px;
    border-radius: 6px;
    background: rgba(244, 63, 94, 0.15);
    color: #f43f5e;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 11.5px;
    flex-shrink: 0;
}

.mji-deck-item__text h4 {
    font-size: 12px;
    font-weight: 600;
    color: var(--mj-text-primary, #f8fafc);
    margin: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

.mji-deck-item__text p {
    font-size: 11px;
    color: var(--mj-text-muted, #64748b);
    margin: 1px 0 0 0;
}

.mji-timeline {
    display: flex;
    flex-direction: column;
    gap: 6px;
    max-height: 210px;
    overflow-y: auto;
    scrollbar-width: thin;
    padding-right: 4px;
}

.mji-timeline-item {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 6px 8px;
    border-radius: 6px;
    border: 1px solid transparent;
    cursor: pointer;
    transition: all 0.15s ease;
}

.mji-timeline-item:hover {
    background: var(--mj-bg-surface-sunken, #090e1a);
    border-color: var(--mj-border-default, #223254);
    transform: translateX(2px);
}

.mji-timeline-item__icon {
    width: 24px;
    height: 24px;
    border-radius: 50%;
    background: var(--mj-bg-surface-sunken, #090e1a);
    border: 1px solid var(--mj-border-default, #223254);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 10px;
    flex-shrink: 0;
    color: var(--mj-brand-primary, #38bdf8);
}

.mji-timeline-item__content {
    flex: 1;
    min-width: 0;
}

.mji-timeline-item__content h5 {
    font-size: 11.5px;
    font-weight: 600;
    color: var(--mj-text-primary, #f8fafc);
    margin: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

.mji-timeline-item__content p {
    font-size: 10.5px;
    color: var(--mj-text-secondary, #94a3b8);
    margin: 1px 0 0 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

.mji-code {
    font-family: 'JetBrains Mono', monospace;
    font-weight: 600;
    color: var(--mj-brand-primary, #38bdf8);
}

.mji-empty-state {
    font-size: 12px;
    color: var(--mj-text-muted, #64748b);
    padding: 16px;
    text-align: center;
    font-style: italic;
}
`;

@Component({
    standalone: true,
    selector: 'mji-issue-overview',
    imports: [
        CommonModule,
        MJCardGridComponent,
        MJCardComponent,
        MJCardToolsDirective,
        MJCardFooterDirective,
    ],
    template: `
        <div class="mji-overview">
            <mj-card-grid>
                
                <!-- Card 1: SLA Status & Resolution Trajectory -->
                <mj-card Title="SLA Status & Lifecycle Trajectory" Subtitle="Resolution Pace & Milestone Stages" Icon="fa-solid fa-stopwatch-20">
                    <div mjCardTools>
                        <span class="mji-code">{{ LifecycleStageLabel }}</span>
                    </div>

                    <div class="mji-chart-bars">
                        <div class="mji-bar-col">
                            <div class="mji-bar-fill" style="height: 100%;"></div>
                            <span class="mji-bar-lbl">Reported</span>
                        </div>
                        <div class="mji-bar-col">
                            <div class="mji-bar-fill" [style.height.%]="IsTriaged ? 100 : 20"></div>
                            <span class="mji-bar-lbl">Triaged</span>
                        </div>
                        <div class="mji-bar-col">
                            <div class="mji-bar-fill" [style.height.%]="IsRootCaused ? 100 : 15"></div>
                            <span class="mji-bar-lbl">Investigate</span>
                        </div>
                        <div class="mji-bar-col">
                            <div class="mji-bar-fill" [style.height.%]="IsFixStaged ? 100 : 10"></div>
                            <span class="mji-bar-lbl">Fix Stage</span>
                        </div>
                        <div class="mji-bar-col">
                            <div class="mji-bar-fill mji-bar-fill--peak" [style.height.%]="IsResolved ? 100 : 10"></div>
                            <span class="mji-bar-lbl">Resolved</span>
                        </div>
                    </div>

                    <div mjCardFooter>
                        <div class="card-metric">
                            <span class="card-metric__label">Severity</span>
                            <span class="card-metric__val" style="color: var(--mj-status-warning);">{{ Record?.Severity || 'Medium' }}</span>
                        </div>
                        <div class="card-metric">
                            <span class="card-metric__label">Priority</span>
                            <span class="card-metric__val">{{ Record?.Priority || 'Medium' }}</span>
                        </div>
                        <div class="card-metric">
                            <span class="card-metric__label">Lifecycle</span>
                            <span class="card-metric__val" style="color: var(--mj-brand-primary);">{{ LifecycleStageLabel }}</span>
                        </div>
                    </div>
                </mj-card>

                <!-- Card 2: Impact & Environment Snapshot -->
                <mj-card Title="Impact & Environment Snapshot" Subtitle="Defect Scope & Configuration" Icon="fa-solid fa-server">
                    <div mjCardTools>
                        <span class="mji-code">{{ AppScopeLabel }}</span>
                    </div>

                    <div class="mji-deck">
                        <div class="mji-deck-item">
                            <div class="mji-deck-item__left">
                                <div class="mji-deck-item__icon">
                                    <i class="fa-solid fa-triangle-exclamation"></i>
                                </div>
                                <div class="mji-deck-item__text">
                                    <h4>Severity: {{ Record?.Severity || 'Medium' }}</h4>
                                    <p>Priority: {{ Record?.Priority || 'Medium' }}</p>
                                </div>
                            </div>
                            <span class="mji-code" style="font-size: 11px;">Active</span>
                        </div>

                        <div class="mji-deck-item">
                            <div class="mji-deck-item__left">
                                <div class="mji-deck-item__icon" style="background: rgba(56, 189, 248, 0.12); color: #38bdf8;">
                                    <i class="fa-solid fa-layer-group"></i>
                                </div>
                                <div class="mji-deck-item__text">
                                    <h4>Application Scope</h4>
                                    <p>{{ AppScopeLabel }}</p>
                                </div>
                            </div>
                            <span class="mji-code" style="font-size: 11px;">Scope</span>
                        </div>
                    </div>

                    <div mjCardFooter>
                        <div class="card-metric">
                            <span class="card-metric__label">Created</span>
                            <span class="card-metric__val">{{ CreatedDateLabel }}</span>
                        </div>
                        <div class="card-metric">
                            <span class="card-metric__label">Resolved Date</span>
                            <span class="card-metric__val" style="color: var(--mj-status-success);">{{ ResolvedDateLabel }}</span>
                        </div>
                        <div class="card-metric">
                            <span class="card-metric__label">Status</span>
                            <span class="card-metric__val">{{ StatusStateLabel }}</span>
                        </div>
                    </div>
                </mj-card>

                <!-- Card 3: Discussion & Activity Trail -->
                <mj-card Title="Incident Response & Discussion" Subtitle="Discussion Timeline & Notes" Icon="fa-solid fa-comments">
                    <div mjCardTools>
                        <span class="mji-code">{{ Comments.length }} Comments</span>
                    </div>

                    <div class="mji-timeline">
                        @if (Comments.length > 0) {
                            @for (c of Comments; track c.ID) {
                                <div class="mji-timeline-item">
                                    <div class="mji-timeline-item__icon">
                                        <i class="fa-solid fa-comment-dots"></i>
                                    </div>
                                    <div class="mji-timeline-item__content">
                                        <h5>{{ c.User }}</h5>
                                        <p>{{ c.Comment }}</p>
                                    </div>
                                </div>
                            }
                        } @else {
                            <div class="mji-empty-state">No comments posted on this issue yet.</div>
                        }
                    </div>

                    <div mjCardFooter>
                        <div class="card-metric">
                            <span class="card-metric__label">Comments</span>
                            <span class="card-metric__val">{{ Comments.length }} Total</span>
                        </div>
                        <div class="card-metric">
                            <span class="card-metric__label">Reporter</span>
                            <span class="card-metric__val">{{ Record?.ReporterEmail || 'Team' }}</span>
                        </div>
                        <div class="card-metric">
                            <span class="card-metric__label">Audit</span>
                            <span class="card-metric__val" style="color: var(--mj-brand-primary);">Logged</span>
                        </div>
                    </div>
                </mj-card>

                <!-- Card 4: Linked Context & Reporter -->
                <mj-card Title="Linked Context & Reporter" Subtitle="Ownership & Origin Details" Icon="fa-solid fa-link">
                    <div mjCardTools>
                        <span class="mji-code">Origin</span>
                    </div>

                    <div class="mji-deck">
                        <div class="mji-deck-item">
                            <div class="mji-deck-item__left">
                                <div class="mji-deck-item__icon" style="background: rgba(139, 92, 246, 0.15); color: #a78bfa;">
                                    <i class="fa-solid fa-envelope"></i>
                                </div>
                                <div class="mji-deck-item__text">
                                    <h4>Reporter: {{ Record?.ReporterEmail || 'Internal User' }}</h4>
                                    <p>Created: {{ CreatedDateLabel }}</p>
                                </div>
                            </div>
                            <span class="mji-code" style="font-size: 11px;">Reporter</span>
                        </div>

                        <div class="mji-deck-item">
                            <div class="mji-deck-item__left">
                                <div class="mji-deck-item__icon" style="background: rgba(16, 185, 129, 0.15); color: #10b981;">
                                    <i class="fa-solid fa-fingerprint"></i>
                                </div>
                                <div class="mji-deck-item__text">
                                    <h4>Issue Number: {{ Record?.IssueNumber || 'Pending' }}</h4>
                                    <p>ID: {{ ShortId }}</p>
                                </div>
                            </div>
                            <span class="mji-code" style="font-size: 11px;">Record</span>
                        </div>
                    </div>

                    <div mjCardFooter>
                        <div class="card-metric">
                            <span class="card-metric__label">Issue #</span>
                            <span class="card-metric__val mji-code">{{ Record?.IssueNumber || '—' }}</span>
                        </div>
                        <div class="card-metric">
                            <span class="card-metric__label">Created</span>
                            <span class="card-metric__val">{{ CreatedDateLabel }}</span>
                        </div>
                        <div class="card-metric">
                            <span class="card-metric__label">State</span>
                            <span class="card-metric__val" style="color: var(--mj-status-success);">Active</span>
                        </div>
                    </div>
                </mj-card>

            </mj-card-grid>
        </div>
    `,
    styles: [ISSUE_OVERVIEW_CSS]
})
export class IssueOverviewComponent implements OnInit, OnChanges {
    @Input() public Record: mjBizAppsIssuesIssueEntity | null = null;
    @Input() public FormComponent: BaseFormComponent | null = null;

    private cdr = inject(ChangeDetectorRef);
    private navService = inject(NavigationService, { optional: true });

    public Comments: IssueCommentSummary[] = [];
    public IsLoading = false;

    public get IsResolved(): boolean {
        return !!this.Record?.ResolvedAt;
    }

    public get IsFixStaged(): boolean {
        return this.IsResolved;
    }

    public get IsRootCaused(): boolean {
        return this.IsFixStaged || this.Comments.length > 0;
    }

    public get IsTriaged(): boolean {
        return !!this.Record?.Severity || !!this.Record?.Priority;
    }

    public get LifecycleStageLabel(): string {
        if (this.IsResolved) return 'Resolved';
        if (this.IsFixStaged) return 'Fix Staged';
        if (this.IsRootCaused) return 'Investigating';
        if (this.IsTriaged) return 'Triaged';
        return 'Reported';
    }

    public get ShortId(): string {
        if (!this.Record?.ID) return '';
        return String(this.Record.ID).substring(0, 8);
    }

    public get AppScopeLabel(): string {
        return this.Record?.AppScope || 'Global Scope';
    }

    public get ResolvedDateLabel(): string {
        if (!this.Record?.ResolvedAt) return 'In Progress';
        return new Date(this.Record.ResolvedAt).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }

    public get StatusStateLabel(): string {
        if (this.Record?.ClosedAt) return 'Closed';
        if (this.Record?.ResolvedAt) return 'Resolved';
        return 'Open';
    }

    public get CreatedDateLabel(): string {
        const raw = this.Record?.Get('__mj_CreatedAt');
        if (!raw) return '—';
        return new Date(raw).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }

    public ngOnInit(): void {
        this.LoadComments();
    }

    public ngOnChanges(changes: SimpleChanges): void {
        if (changes['Record'] && !changes['Record'].firstChange) {
            this.LoadComments();
        }
    }

    public async LoadComments(): Promise<void> {
        if (!this.Record?.ID) return;
        this.IsLoading = true;

        try {
            const rv = new RunView();
            const res = await rv.RunView<Record<string, unknown>>({
                EntityName: 'MJ_BizApps_Issues: Issue Comments',
                ExtraFilter: `IssueID = '${this.Record.ID}'`,
                OrderBy: '__mj_CreatedAt DESC',
                MaxRows: 10,
                ResultType: 'simple'
            });

            if (res?.Success && res.Results) {
                this.Comments = res.Results.map((c: Record<string, unknown>) => ({
                    ID: String(c['ID'] || ''),
                    Comment: String(c['Comment'] || c['Body'] || 'Comment posted'),
                    CreatedAt: new Date(String(c['__mj_CreatedAt'] || Date.now())),
                    User: String(c['User'] || 'Team Member')
                }));
            }
        } catch (e) {
            console.warn('[IssueOverview] Error loading comments:', e);
        } finally {
            this.IsLoading = false;
            this.cdr.detectChanges();
        }
    }
}
