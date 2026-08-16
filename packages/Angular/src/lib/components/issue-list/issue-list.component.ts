import { Component, Input, Output, EventEmitter, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import type { IssueCardItem } from '../issue-kanban/issue-kanban.component';

const ISSUE_LIST_CSS = `
.mji-list-container {
    background: var(--mj-bg-surface-card, #141f36);
    border: 1px solid var(--mj-border-default, #223254);
    border-radius: var(--mj-radius-lg, 12px);
    overflow: hidden;
}

.mji-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12.5px;
    text-align: left;
}

.mji-table th {
    padding: 10px 14px;
    color: var(--mj-text-muted, #64748b);
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    border-bottom: 1px solid var(--mj-border-default, #223254);
    background: var(--mj-bg-surface, #111a2e);
}

.mji-table td {
    padding: 12px 14px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.04);
    color: var(--mj-text-secondary, #94a3b8);
}

.mji-table tr:hover td {
    background: var(--mj-bg-surface-sunken, #090e1a);
    color: var(--mj-text-primary, #f8fafc);
    cursor: pointer;
}

.mji-issue-num {
    font-family: 'JetBrains Mono', monospace;
    font-weight: 700;
    color: var(--mj-brand-primary, #38bdf8);
}

.mji-title-cell {
    color: var(--mj-text-primary, #f8fafc);
    font-weight: 600;
    max-width: 320px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}

.mji-pill {
    font-size: 10.5px;
    font-weight: 700;
    padding: 2px 7px;
    border-radius: 4px;
    display: inline-flex;
    align-items: center;
}

.mji-pill--critical { background: rgba(244, 63, 94, 0.2); color: #f43f5e; border: 1px solid rgba(244, 63, 94, 0.4); }
.mji-pill--high { background: rgba(245, 158, 11, 0.2); color: #f59e0b; border: 1px solid rgba(245, 158, 11, 0.4); }
.mji-pill--medium { background: rgba(56, 189, 248, 0.15); color: #38bdf8; border: 1px solid rgba(56, 189, 248, 0.3); }
.mji-pill--low { background: rgba(148, 163, 184, 0.15); color: #94a3b8; border: 1px solid rgba(148, 163, 184, 0.3); }

.mji-pill--status {
    background: var(--mj-bg-surface-elevated, #1a2744);
    border: 1px solid var(--mj-border-default, #223254);
    color: var(--mj-text-primary, #f8fafc);
}

.mji-empty {
    padding: 32px;
    text-align: center;
    color: var(--mj-text-muted, #64748b);
    font-style: italic;
}
`;

@Component({
    selector: 'bizapps-issue-list',
    standalone: true,
    imports: [CommonModule, FormsModule],
    changeDetection: ChangeDetectionStrategy.OnPush,
    template: `
        <div class="mji-list-container">
            @if (Issues.length > 0) {
                <table class="mji-table">
                    <thead>
                        <tr>
                            <th style="width: 110px;">Issue #</th>
                            <th>Title</th>
                            <th style="width: 100px;">Severity</th>
                            <th style="width: 100px;">Priority</th>
                            <th style="width: 120px;">Status</th>
                            <th style="width: 110px;">Scope</th>
                            <th style="width: 160px;">Reporter</th>
                            <th style="width: 100px;">Created</th>
                        </tr>
                    </thead>
                    <tbody>
                        @for (item of Issues; track item.ID) {
                            <tr (click)="IssueSelected.emit(item)">
                                <td>
                                    <span class="mji-issue-num">{{ item.IssueNumber || 'ISSUE' }}</span>
                                </td>
                                <td>
                                    <div class="mji-title-cell">{{ item.Title }}</div>
                                </td>
                                <td>
                                    <span [class]="GetSeverityPillClass(item.Severity)">{{ item.Severity }}</span>
                                </td>
                                <td>
                                    <span [class]="GetSeverityPillClass(item.Priority)">{{ item.Priority }}</span>
                                </td>
                                <td>
                                    <span class="mji-pill mji-pill--status">{{ item.StatusName || 'Reported' }}</span>
                                </td>
                                <td>
                                    <span>{{ item.AppScope || 'Global' }}</span>
                                </td>
                                <td>
                                    <span>{{ item.ReporterEmail || 'Internal' }}</span>
                                </td>
                                <td>
                                    <span>{{ FormatDate(item.CreatedAt) }}</span>
                                </td>
                            </tr>
                        }
                    </tbody>
                </table>
            } @else {
                <div class="mji-empty">No issues match the current filter criteria.</div>
            }
        </div>
    `,
    styles: [ISSUE_LIST_CSS]
})
export class IssueListComponent {
    @Input() public Issues: IssueCardItem[] = [];
    @Output() public IssueSelected = new EventEmitter<IssueCardItem>();

    public GetSeverityPillClass(sev: string): string {
        switch (sev) {
            case 'Critical': return 'mji-pill mji-pill--critical';
            case 'High': return 'mji-pill mji-pill--high';
            case 'Low': return 'mji-pill mji-pill--low';
            default: return 'mji-pill mji-pill--medium';
        }
    }

    public FormatDate(d: Date): string {
        if (!d) return '—';
        return new Date(d).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }
}
