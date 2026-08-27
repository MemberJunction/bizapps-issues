import { Component, Input, Output, EventEmitter, OnInit, OnChanges, SimpleChanges, ChangeDetectionStrategy, ChangeDetectorRef, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RunView, CompositeKey } from '@memberjunction/core';
import { NavigationService } from '@memberjunction/ng-shared';
import type { mjBizAppsIssuesIssueEntity, mjBizAppsIssuesIssueStatusEntity } from '@mj-biz-apps/issues-entities';

export interface IssueCardItem {
    ID: string;
    IssueNumber: string;
    Title: string;
    Description: string;
    Severity: 'Critical' | 'High' | 'Low' | 'Medium';
    Priority: 'Critical' | 'High' | 'Low' | 'Medium';
    StatusID: string;
    StatusName: string;
    ReporterEmail: string;
    AppScope: string;
    CreatedAt: Date;
    ResolvedAt: Date | null;
}

export interface KanbanColumn {
    ID: string;
    Name: string;
    Items: IssueCardItem[];
    BadgeClass: string;
}

const ISSUE_KANBAN_CSS = `
.mji-kanban {
    display: flex;
    gap: 16px;
    overflow-x: auto;
    padding-bottom: 12px;
    min-height: 520px;
    scrollbar-width: thin;
}

.mji-column {
    flex: 0 0 310px;
    background: var(--mj-bg-surface-card, #141f36);
    border: 1px solid var(--mj-border-default, #223254);
    border-radius: var(--mj-radius-lg, 12px);
    display: flex;
    flex-direction: column;
    max-height: 780px;
}

.mji-column-header {
    padding: 12px 14px;
    border-bottom: 1px solid var(--mj-border-default, #223254);
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: var(--mj-bg-surface, #111a2e);
    border-radius: 12px 12px 0 0;
}

.mji-column-title {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 13px;
    font-weight: 700;
    color: var(--mj-text-primary, #f8fafc);
}

.mji-column-count {
    font-size: 11px;
    font-weight: 700;
    padding: 1px 7px;
    border-radius: 9999px;
    background: var(--mj-bg-surface-elevated, #1a2744);
    color: var(--mj-text-secondary, #94a3b8);
    border: 1px solid var(--mj-border-default, #223254);
}

.mji-card-list {
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 10px;
    overflow-y: auto;
    flex: 1;
    scrollbar-width: thin;
}

.mji-card {
    background: var(--mj-bg-surface, #111a2e);
    border: 1px solid var(--mj-border-default, #223254);
    border-radius: 8px;
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 8px;
    cursor: pointer;
    transition: all 0.15s ease;
}

.mji-card:hover {
    border-color: var(--mj-brand-primary, #38bdf8);
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.25);
}

.mji-card-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
}

.mji-issue-num {
    font-family: 'JetBrains Mono', monospace;
    font-size: 11px;
    font-weight: 700;
    color: var(--mj-brand-primary, #38bdf8);
}

.mji-pills {
    display: flex;
    align-items: center;
    gap: 6px;
}

.mji-pill {
    font-size: 10px;
    font-weight: 700;
    padding: 1px 6px;
    border-radius: 4px;
    text-transform: uppercase;
    letter-spacing: 0.03em;
}

.mji-pill--critical { background: rgba(244, 63, 94, 0.2); color: #f43f5e; border: 1px solid rgba(244, 63, 94, 0.4); }
.mji-pill--high { background: rgba(245, 158, 11, 0.2); color: #f59e0b; border: 1px solid rgba(245, 158, 11, 0.4); }
.mji-pill--medium { background: rgba(56, 189, 248, 0.15); color: #38bdf8; border: 1px solid rgba(56, 189, 248, 0.3); }
.mji-pill--low { background: rgba(148, 163, 184, 0.15); color: #94a3b8; border: 1px solid rgba(148, 163, 184, 0.3); }

.mji-card-title {
    font-size: 13px;
    font-weight: 600;
    color: var(--mj-text-primary, #f8fafc);
    margin: 0;
    line-height: 1.35;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
}

.mji-card-meta {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    font-size: 11px;
    color: var(--mj-text-muted, #64748b);
    padding-top: 6px;
    border-top: 1px solid rgba(255, 255, 255, 0.04);
}

.mji-card-reporter {
    display: flex;
    align-items: center;
    gap: 4px;
    max-width: 140px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}

.mji-empty-col {
    padding: 24px 12px;
    text-align: center;
    font-size: 11.5px;
    color: var(--mj-text-muted, #64748b);
    font-style: italic;
}
`;

@Component({
    selector: 'bizapps-issue-kanban',
    standalone: true,
    imports: [CommonModule, FormsModule],
    changeDetection: ChangeDetectionStrategy.OnPush,
    template: `
        <div class="mji-kanban">
            @for (col of Columns; track col.ID) {
                <div class="mji-column">
                    <div class="mji-column-header">
                        <div class="mji-column-title">
                            <span>{{ col.Name }}</span>
                        </div>
                        <span class="mji-column-count">{{ col.Items.length }}</span>
                    </div>

                    <div class="mji-card-list">
                        @if (col.Items.length > 0) {
                            @for (item of col.Items; track item.ID) {
                                <div class="mji-card" (click)="OnCardClick(item)">
                                    <div class="mji-card-top">
                                        <span class="mji-issue-num">{{ item.IssueNumber || 'ISSUE' }}</span>
                                        <div class="mji-pills">
                                            <span [class]="GetSeverityPillClass(item.Severity)">{{ item.Severity }}</span>
                                            @if (item.AppScope) {
                                                <span class="mji-pill mji-pill--low">{{ item.AppScope }}</span>
                                            }
                                        </div>
                                    </div>

                                    <h3 class="mji-card-title">{{ item.Title }}</h3>

                                    <div class="mji-card-meta">
                                        <span class="mji-card-reporter">
                                            <i class="fa-solid fa-user-circle"></i>
                                            {{ item.ReporterEmail || 'Internal' }}
                                        </span>
                                        <span>{{ FormatTimeAgo(item.CreatedAt) }}</span>
                                    </div>
                                </div>
                            }
                        } @else {
                            <div class="mji-empty-col">No issues in this stage</div>
                        }
                    </div>
                </div>
            }
        </div>
    `,
    styles: [ISSUE_KANBAN_CSS]
})
export class IssueKanbanComponent implements OnInit, OnChanges {
    @Input() public Issues: IssueCardItem[] = [];
    @Input() public Statuses: mjBizAppsIssuesIssueStatusEntity[] = [];
    @Output() public IssueSelected = new EventEmitter<IssueCardItem>();
    @Output() public IssueOpenRecord = new EventEmitter<IssueCardItem>();

    private cdr = inject(ChangeDetectorRef);
    private navService = inject(NavigationService, { optional: true });

    public Columns: KanbanColumn[] = [];

    public ngOnInit(): void {
        this.BuildColumns();
    }

    public ngOnChanges(changes: SimpleChanges): void {
        if (changes['Issues'] || changes['Statuses']) {
            this.BuildColumns();
        }
    }

    public BuildColumns(): void {
        if (!this.Statuses || this.Statuses.length === 0) {
            // Default standard columns if status table not yet loaded
            const defaultStages = ['Reported', 'Triaged', 'In Progress', 'Fix Staged', 'Resolved', 'Closed'];
            this.Columns = defaultStages.map((name, idx) => ({
                ID: `stage-${idx}`,
                Name: name,
                Items: this.Issues.filter(i => (i.StatusName || 'Reported').toLowerCase() === name.toLowerCase()),
                BadgeClass: ''
            }));
        } else {
            this.Columns = this.Statuses.map(s => ({
                ID: s.ID,
                Name: s.Name,
                Items: this.Issues.filter(i => i.StatusID === s.ID || i.StatusName?.toLowerCase() === s.Name?.toLowerCase()),
                BadgeClass: ''
            }));
        }
        this.cdr.markForCheck();
    }

    public OnCardClick(item: IssueCardItem): void {
        this.IssueSelected.emit(item);
    }

    public GetSeverityPillClass(sev: string): string {
        switch (sev) {
            case 'Critical': return 'mji-pill mji-pill--critical';
            case 'High': return 'mji-pill mji-pill--high';
            case 'Low': return 'mji-pill mji-pill--low';
            default: return 'mji-pill mji-pill--medium';
        }
    }

    public FormatTimeAgo(d: Date): string {
        if (!d) return '—';
        const diffMs = Date.now() - new Date(d).getTime();
        const diffHrs = Math.floor(diffMs / (1000 * 60 * 60));
        if (diffHrs < 1) return 'just now';
        if (diffHrs < 24) return `${diffHrs}h ago`;
        const diffDays = Math.floor(diffHrs / 24);
        return `${diffDays}d ago`;
    }
}
