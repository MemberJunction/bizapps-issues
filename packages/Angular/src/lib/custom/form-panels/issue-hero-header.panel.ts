import { Component, OnInit, ChangeDetectorRef, inject } from '@angular/core';
import { RegisterClassEx } from '@memberjunction/global';
import { BaseFormPanel } from '@memberjunction/ng-base-forms';
import { UserInfoEngine } from '@memberjunction/core-entities';
import type { mjBizAppsIssuesIssueEntity } from '@mj-biz-apps/issues-entities';

const ISSUE_HERO_CSS = `
.mji-hero {
    display: flex;
    flex-direction: column;
    gap: var(--mj-space-3, 12px);
    padding: 16px 20px;
    margin-bottom: 16px;
    background: var(--mj-bg-surface-card, #141f36);
    border: 1px solid var(--mj-border-default, #223254);
    border-radius: var(--mj-radius-lg, 14px);
    transition: all 0.2s ease;
}

.mji-hero--collapsed {
    padding: 12px 16px;
}

.mji-hero__main-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    width: 100%;
}

.mji-hero__identity {
    display: flex;
    align-items: center;
    gap: 14px;
    min-width: 0;
}

.mji-hero__avatar {
    width: 44px;
    height: 44px;
    border-radius: 10px;
    background: linear-gradient(135deg, #f43f5e, #be123c);
    color: #ffffff;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 16px;
    flex-shrink: 0;
}

.mji-hero--collapsed .mji-hero__avatar {
    width: 30px;
    height: 30px;
    font-size: 12px;
    border-radius: 6px;
}

.mji-hero__copy {
    display: flex;
    flex-direction: column;
    gap: 3px;
    min-width: 0;
}

.mji-hero__title-row {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
}

.mji-hero__title {
    font-size: 17px;
    font-weight: 700;
    color: var(--mj-text-primary, #f8fafc);
    margin: 0;
    line-height: 1.25;
}

.mji-hero--collapsed .mji-hero__title {
    font-size: 14px;
}

.mji-hero__meta {
    display: flex;
    align-items: center;
    gap: 8px;
    color: var(--mj-text-secondary, #94a3b8);
    font-size: 12.5px;
}

.mji-hero__collapse-btn {
    width: 30px;
    height: 30px;
    border-radius: var(--mj-radius-sm, 6px);
    background: var(--mj-bg-surface, #111a2e);
    border: 1px solid var(--mj-border-default, #223254);
    color: var(--mj-text-secondary, #94a3b8);
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: all 0.15s ease;
    flex-shrink: 0;
}

.mji-hero__collapse-btn:hover {
    color: var(--mj-text-primary, #f8fafc);
    border-color: var(--mj-brand-primary, #38bdf8);
    background: rgba(56, 189, 248, 0.1);
}

.mji-hero__expanded {
    padding-top: 14px;
    border-top: 1px solid var(--mj-border-subtle, rgba(255, 255, 255, 0.06));
    display: flex;
    flex-direction: column;
    gap: 12px;
    animation: mjiFadeIn 0.2s ease;
}

.mji-hero__stats {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(8.5rem, 1fr));
    gap: 12px;
}

.mji-stat {
    display: flex;
    flex-direction: column;
    gap: 2px;
}

.mji-stat__label {
    font-size: 10px;
    font-weight: 700;
    color: var(--mj-text-muted, #64748b);
    text-transform: uppercase;
    letter-spacing: 0.04em;
}

.mji-stat__value {
    font-size: 14px;
    font-weight: 700;
    color: var(--mj-text-primary, #f8fafc);
}

.mji-stat__value--accent { color: var(--mj-brand-primary, #38bdf8); }
.mji-stat__value--warn { color: var(--mj-status-warning, #f59e0b); }
.mji-stat__value--danger { color: var(--mj-status-error, #ef4444); }
.mji-stat__value--success { color: var(--mj-status-success, #10b981); }

.mji-badge {
    font-size: 11px;
    font-weight: 600;
    padding: 2px 8px;
    border-radius: 9999px;
    display: inline-flex;
    align-items: center;
    gap: 4px;
}

.mji-badge--danger { background: rgba(244, 63, 94, 0.15); color: #f43f5e; border: 1px solid rgba(244, 63, 94, 0.3); }
.mji-badge--warn { background: rgba(245, 158, 11, 0.15); color: #f59e0b; border: 1px solid rgba(245, 158, 11, 0.3); }
.mji-badge--info { background: rgba(56, 189, 248, 0.15); color: #38bdf8; border: 1px solid rgba(56, 189, 248, 0.3); }
.mji-badge--success { background: rgba(16, 185, 129, 0.15); color: #10b981; border: 1px solid rgba(16, 185, 129, 0.3); }

.mji-code {
    font-family: 'JetBrains Mono', monospace;
    font-weight: 600;
    color: var(--mj-brand-primary, #38bdf8);
}

@keyframes mjiFadeIn {
    from { opacity: 0; transform: translateY(-4px); }
    to { opacity: 1; transform: translateY(0); }
}
`;

@RegisterClassEx(BaseFormPanel, {
    key: 'form-panel:Issues:header',
    metadata: {
        entity: 'MJ_BizApps_Issues: Issues',
        slot: 'header',
        sortKey: 100,
        contributionKey: 'header',
    },
})
@Component({
    standalone: false,
    selector: 'mji-issue-hero-header-panel',
    template: `
        <div class="mji-hero" [class.mji-hero--collapsed]="IsCollapsed">
            <div class="mji-hero__main-row">
                <div class="mji-hero__identity">
                    <div class="mji-hero__avatar">
                        <i class="fa-solid fa-bug" aria-hidden="true"></i>
                    </div>
                    <div class="mji-hero__copy">
                        <div class="mji-hero__title-row">
                            @if (IssueNumber) {
                                <span class="mji-code" style="font-size: 14px;">{{ IssueNumber }}</span>
                            }
                            <h1 class="mji-hero__title">{{ Title }}</h1>
                            <span [class]="SeverityBadgeClass">{{ Severity }}</span>
                            <span [class]="PriorityBadgeClass">{{ Priority }}</span>
                        </div>
                        <div class="mji-hero__meta">
                            @if (ReporterInfo) {
                                <span>Reported by <strong>{{ ReporterInfo }}</strong></span>
                                <span>&bull;</span>
                            }
                            @if (AppScope) {
                                <span>Scope: <strong>{{ AppScope }}</strong></span>
                                <span>&bull;</span>
                            }
                            <span>Severity: <strong>{{ Severity }}</strong></span>
                        </div>
                    </div>
                </div>

                <button class="mji-hero__collapse-btn" (click)="ToggleCollapse()" [title]="IsCollapsed ? 'Expand details' : 'Collapse details'" type="button">
                    <i class="fa-solid" [class.fa-chevron-up]="!IsCollapsed" [class.fa-chevron-down]="IsCollapsed"></i>
                </button>
            </div>

            @if (!IsCollapsed) {
                <div class="mji-hero__expanded">
                    <div class="mji-hero__stats">
                        <div class="mji-stat">
                            <span class="mji-stat__label">Severity</span>
                            <span class="mji-stat__value" [class.mji-stat__value--danger]="Severity === 'Critical' || Severity === 'High'">
                                {{ Severity }}
                            </span>
                        </div>
                        <div class="mji-stat">
                            <span class="mji-stat__label">Priority</span>
                            <span class="mji-stat__value" [class.mji-stat__value--warn]="Priority === 'Critical' || Priority === 'High'">
                                {{ Priority }}
                            </span>
                        </div>
                        <div class="mji-stat">
                            <span class="mji-stat__label">Lifecycle</span>
                            <span class="mji-stat__value mji-stat__value--accent">{{ StatusLabel }}</span>
                        </div>
                        <div class="mji-stat">
                            <span class="mji-stat__label">App Scope</span>
                            <span class="mji-stat__value mji-stat__value--success">{{ AppScope || 'Global' }}</span>
                        </div>
                    </div>
                </div>
            }
        </div>
    `,
    styles: [ISSUE_HERO_CSS]
})
export class IssueHeroHeaderPanel extends BaseFormPanel<mjBizAppsIssuesIssueEntity> implements OnInit {
    private cdr = inject(ChangeDetectorRef);
    public IsCollapsed = false;

    private get StorageKey(): string {
        const id = this.Record?.ID ? String(this.Record.ID).toLowerCase() : 'new';
        return `mj.issueHero.collapsed.${id}`;
    }

    public ngOnInit(): void {
        const raw = UserInfoEngine.Instance.GetSetting(this.StorageKey);
        if (raw) {
            try {
                this.IsCollapsed = JSON.parse(raw) === true;
            } catch {
                this.IsCollapsed = false;
            }
        }
    }

    public ToggleCollapse(): void {
        this.IsCollapsed = !this.IsCollapsed;
        UserInfoEngine.Instance.SetSettingDebounced(this.StorageKey, JSON.stringify(this.IsCollapsed));
        this.cdr.detectChanges();
    }

    public get IssueNumber(): string {
        return this.Record?.IssueNumber || '';
    }

    public get Title(): string {
        return this.Record?.Title || 'New Issue';
    }

    public get Severity(): string {
        return this.Record?.Severity || 'Medium';
    }

    public get Priority(): string {
        return this.Record?.Priority || 'Medium';
    }

    public get AppScope(): string {
        return this.Record?.AppScope || '';
    }

    public get ReporterInfo(): string {
        return this.Record?.ReporterEmail || 'Internal Team';
    }

    public get StatusLabel(): string {
        if (this.Record?.ClosedAt) return 'Closed';
        if (this.Record?.ResolvedAt) return 'Resolved';
        return 'Active Triage';
    }

    public get SeverityBadgeClass(): string {
        switch (this.Severity) {
            case 'Critical': return 'mji-badge mji-badge--danger';
            case 'High': return 'mji-badge mji-badge--warn';
            case 'Low': return 'mji-badge mji-badge--info';
            default: return 'mji-badge mji-badge--info';
        }
    }

    public get PriorityBadgeClass(): string {
        switch (this.Priority) {
            case 'Critical': return 'mji-badge mji-badge--danger';
            case 'High': return 'mji-badge mji-badge--warn';
            default: return 'mji-badge mji-badge--info';
        }
    }
}
