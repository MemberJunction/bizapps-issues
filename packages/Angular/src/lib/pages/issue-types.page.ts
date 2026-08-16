import { Component, OnInit, ChangeDetectionStrategy, ChangeDetectorRef, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RunView } from '@memberjunction/core';
import type { mjBizAppsIssuesIssueTypeEntity, mjBizAppsIssuesIssueStatusEntity } from '@mj-biz-apps/issues-entities';

const TYPES_CSS = `
.mji-types-page {
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 16px;
    height: 100%;
    overflow-y: auto;
    background: var(--mj-bg-surface-sunken, #090e1a);
}

.mji-types-header {
    background: var(--mj-bg-surface-card, #141f36);
    border: 1px solid var(--mj-border-default, #223254);
    border-radius: 12px;
    padding: 16px 20px;
    display: flex;
    align-items: center;
    justify-content: space-between;
}

.mji-grid-2 {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(360px, 1fr));
    gap: 16px;
}

.mji-card {
    background: var(--mj-bg-surface-card, #141f36);
    border: 1px solid var(--mj-border-default, #223254);
    border-radius: 12px;
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 12px;
}

.mji-card-h {
    font-size: 14px;
    font-weight: 700;
    color: var(--mj-text-primary, #f8fafc);
    display: flex;
    align-items: center;
    gap: 8px;
}

.mji-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12px;
}

.mji-table th {
    padding: 8px 10px;
    color: var(--mj-text-muted, #64748b);
    font-size: 10.5px;
    font-weight: 700;
    text-transform: uppercase;
    border-bottom: 1px solid var(--mj-border-default, #223254);
    text-align: left;
}

.mji-table td {
    padding: 8px 10px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.04);
    color: var(--mj-text-secondary, #94a3b8);
}
`;

@Component({
    selector: 'bizapps-issue-types-page',
    standalone: true,
    imports: [CommonModule, FormsModule],
    changeDetection: ChangeDetectionStrategy.OnPush,
    template: `
        <div class="mji-types-page">
            <div class="mji-types-header">
                <div style="display:flex; align-items:center; gap:12px;">
                    <div style="width:38px; height:38px; border-radius:8px; background:linear-gradient(135deg, #6366f1, #4f46e5); color:#fff; display:flex; align-items:center; justify-content:center; font-size:16px;">
                        <i class="fa-solid fa-tags"></i>
                    </div>
                    <div>
                        <h2 style="font-size:16px; font-weight:700; color:var(--mj-text-primary); margin:0;">Issue Types &amp; Lifecycle Workflows</h2>
                        <p style="font-size:12px; color:var(--mj-text-secondary); margin:2px 0 0 0;">Classification types and sequence stages configured for issues.</p>
                    </div>
                </div>
            </div>

            <div class="mji-grid-2">
                <!-- 1. Issue Types -->
                <div class="mji-card">
                    <div class="mji-card-h">
                        <i class="fa-solid fa-folder-tree" style="color:var(--mj-brand-primary);"></i>
                        Issue Types ({{ Types.length }})
                    </div>
                    <table class="mji-table">
                        <thead>
                            <tr>
                                <th>Name</th>
                                <th>Description</th>
                                <th>Default Priority</th>
                            </tr>
                        </thead>
                        <tbody>
                            @for (t of Types; track t.ID) {
                                <tr>
                                    <td style="color:var(--mj-text-primary); font-weight:600;">
                                        <i [class]="t.IconClass || 'fa-solid fa-tag'" style="margin-right: 6px; color: var(--mj-brand-primary);"></i>
                                        {{ t.Name }}
                                    </td>
                                    <td>{{ t.Description || 'Standard issue type' }}</td>
                                    <td>{{ t.DefaultPriority || 'Medium' }}</td>
                                </tr>
                            }
                        </tbody>
                    </table>
                </div>

                <!-- 2. Issue Lifecycle Statuses -->
                <div class="mji-card">
                    <div class="mji-card-h">
                        <i class="fa-solid fa-bars-staggered" style="color:#10b981;"></i>
                        Lifecycle Statuses ({{ Statuses.length }})
                    </div>
                    <table class="mji-table">
                        <thead>
                            <tr>
                                <th>Seq</th>
                                <th>Status Name</th>
                                <th>Resolved</th>
                                <th>Terminal</th>
                            </tr>
                        </thead>
                        <tbody>
                            @for (s of Statuses; track s.ID) {
                                <tr>
                                    <td>{{ s.Sequence }}</td>
                                    <td style="color:var(--mj-text-primary); font-weight:600;">{{ s.Name }}</td>
                                    <td>{{ s.IsResolved ? 'Yes' : 'No' }}</td>
                                    <td>{{ s.IsTerminal ? 'Yes' : 'No' }}</td>
                                </tr>
                            }
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    `,
    styles: [TYPES_CSS]
})
export class IssueTypesPageComponent implements OnInit {
    private cdr = inject(ChangeDetectorRef);

    public Types: mjBizAppsIssuesIssueTypeEntity[] = [];
    public Statuses: mjBizAppsIssuesIssueStatusEntity[] = [];

    public ngOnInit(): void {
        this.LoadData();
    }

    public async LoadData(): Promise<void> {
        try {
            const rv = new RunView();
            const typeRes = await rv.RunView<mjBizAppsIssuesIssueTypeEntity>({
                EntityName: 'MJ_BizApps_Issues: Issue Types',
                ResultType: 'entity_object'
            });
            if (typeRes?.Success && typeRes.Results) {
                this.Types = typeRes.Results;
            }

            const statusRes = await rv.RunView<mjBizAppsIssuesIssueStatusEntity>({
                EntityName: 'MJ_BizApps_Issues: Issue Status',
                OrderBy: 'Sequence ASC',
                ResultType: 'entity_object'
            });
            if (statusRes?.Success && statusRes.Results) {
                this.Statuses = statusRes.Results;
            }
        } catch (e) {
            console.error('[IssueTypes] Failed to load data:', e);
        } finally {
            this.cdr.markForCheck();
        }
    }
}
