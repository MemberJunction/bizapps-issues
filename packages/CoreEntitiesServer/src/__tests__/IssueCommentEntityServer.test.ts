import { describe, it, expect, beforeEach, vi } from 'vitest';

// ---------------------------------------------------------------------------
// IssueCommentEntityServer.Save() owns two authorship guarantees:
//   1. INSERT — AuthorPersonID/AuthorEmail are stamped from ContextCurrentUser
//      (Person resolved via People.LinkedUserID with an Email fallback),
//      overriding whatever the client supplied.
//   2. UPDATE — authorship fields are immutable, and content edits (Body/
//      Source/IssueID) are rejected unless the context user IS the author.
//
// We mock the base entity (controllable stub), RunView (canned People rows),
// and core/global stubs — mirroring IssueEntityServer.test.ts.
// ---------------------------------------------------------------------------

const baseSaveMock = vi.fn(async () => true);

interface FieldInfo {
  Dirty: boolean;
  OldValue: string | null;
}
const fieldInfo: Record<string, FieldInfo> = {};

interface StubUser {
  ID: string;
  Email?: string;
}

const USER: StubUser = { ID: 'U-1', Email: 'user@example.com' };

const baseState = {
  IsSaved: false,
  ID: 'CMT-1',
  IssueID: 'ISS-1',
  Body: 'hello',
  Source: 'internal' as 'inbound' | 'internal' | 'outbound',
  AuthorPersonID: null as string | null,
  AuthorEmail: null as string | null,
  ContextCurrentUser: USER as StubUser | undefined,
};

vi.mock('@mj-biz-apps/issues-entities', () => {
  class StubIssueCommentEntity {
    get IsSaved(): boolean { return baseState.IsSaved; }
    get ID(): string { return baseState.ID; }
    get IssueID(): string { return baseState.IssueID; }
    get Body(): string { return baseState.Body; }
    get Source(): 'inbound' | 'internal' | 'outbound' { return baseState.Source; }
    get AuthorPersonID(): string | null { return baseState.AuthorPersonID; }
    set AuthorPersonID(v: string | null) { baseState.AuthorPersonID = v; }
    get AuthorEmail(): string | null { return baseState.AuthorEmail; }
    set AuthorEmail(v: string | null) { baseState.AuthorEmail = v; }
    get ContextCurrentUser(): StubUser | undefined { return baseState.ContextCurrentUser; }
    GetFieldByName(name: string): FieldInfo { return fieldInfo[name] ?? { Dirty: false, OldValue: null }; }
    async Save(): Promise<boolean> { return baseSaveMock(); }
  }
  return { mjBizAppsIssuesIssueCommentEntity: StubIssueCommentEntity };
});

interface StubRunViewParams {
  EntityName: string;
  ExtraFilter?: string;
  Fields?: string[];
  ResultType?: string;
}

// People rows the mocked RunView returns; params captured for filter assertions.
let peopleRows: Array<{ ID: string; LinkedUserID: string | null; Email: string | null }> = [];
let runViewSuccess = true;
let lastRunViewParams: StubRunViewParams | null = null;
const runViewMock = vi.fn(async (params: StubRunViewParams, _contextUser?: StubUser) => {
  lastRunViewParams = params;
  return {
    Success: runViewSuccess,
    Results: peopleRows,
    ErrorMessage: runViewSuccess ? undefined : 'boom',
  };
});

vi.mock('@memberjunction/core', () => ({
  BaseEntity: class {},
  LogError: vi.fn(),
  RunView: class {
    async RunView(params: StubRunViewParams, contextUser?: StubUser) {
      return runViewMock(params, contextUser);
    }
  },
}));
vi.mock('@memberjunction/global', () => ({
  RegisterClass: () => <T>(target: T): T => target,
  EscapeSQLString: (value: string | null | undefined): string =>
    value == null ? '' : value.replace(/\0/g, '').replace(/'/g, "''"),
  UUIDsEqual: (a: string | null | undefined, b: string | null | undefined): boolean =>
    a != null && b != null && a.toLowerCase() === b.toLowerCase(),
}));

import { IssueCommentEntityServer } from '../IssueCommentEntityServer.js';

beforeEach(() => {
  vi.clearAllMocks();
  for (const k of Object.keys(fieldInfo)) delete fieldInfo[k];
  Object.assign(baseState, {
    IsSaved: false,
    ID: 'CMT-1',
    IssueID: 'ISS-1',
    Body: 'hello',
    Source: 'internal' as const,
    AuthorPersonID: null,
    AuthorEmail: null,
    ContextCurrentUser: USER,
  });
  peopleRows = [];
  runViewSuccess = true;
  lastRunViewParams = null;
});

// ─── 1. Insert: server-stamped authorship ─────────────────────────────────────
describe('IssueCommentEntityServer — author stamping on insert', () => {
  it('stamps AuthorPersonID from the LinkedUserID-matched Person, overriding client values', async () => {
    baseState.AuthorPersonID = 'P-SPOOFED';
    baseState.AuthorEmail = 'spoof@example.com';
    peopleRows = [{ ID: 'P-REAL', LinkedUserID: 'U-1', Email: 'other@example.com' }];
    const ok = await new IssueCommentEntityServer().Save();
    expect(ok).toBe(true);
    expect(baseState.AuthorPersonID).toBe('P-REAL');
    expect(baseState.AuthorEmail).toBe('user@example.com');
    expect(baseSaveMock).toHaveBeenCalledOnce();
  });

  it('falls back to an Email-matched Person when no LinkedUserID matches', async () => {
    peopleRows = [{ ID: 'P-EMAIL', LinkedUserID: null, Email: 'USER@example.com' }];
    await new IssueCommentEntityServer().Save();
    expect(baseState.AuthorPersonID).toBe('P-EMAIL');
  });

  it('stamps AuthorPersonID null + AuthorEmail from the user when no Person exists', async () => {
    baseState.AuthorPersonID = 'P-SPOOFED';
    peopleRows = [];
    await new IssueCommentEntityServer().Save();
    expect(baseState.AuthorPersonID).toBeNull();
    expect(baseState.AuthorEmail).toBe('user@example.com');
  });

  it('treats a failed Person lookup as "no Person" (email still stamped)', async () => {
    runViewSuccess = false;
    await new IssueCommentEntityServer().Save();
    expect(baseState.AuthorPersonID).toBeNull();
    expect(baseState.AuthorEmail).toBe('user@example.com');
  });

  it('escapes NUL bytes and single quotes in the Person lookup filter', async () => {
    baseState.ContextCurrentUser = { ID: "U-1'bad\0", Email: "o'brien\0@example.com" };
    await new IssueCommentEntityServer().Save();
    expect(lastRunViewParams?.ExtraFilter).toBe(
      "LinkedUserID='U-1''bad' OR Email='o''brien@example.com'",
    );
  });

  it('rejects an insert with no context user', async () => {
    baseState.ContextCurrentUser = undefined;
    await expect(new IssueCommentEntityServer().Save()).rejects.toThrow(/context user/);
    expect(baseSaveMock).not.toHaveBeenCalled();
  });
});

// ─── 2. Update: immutable authorship + author-only content edits ─────────────
describe('IssueCommentEntityServer — update guards', () => {
  beforeEach(() => {
    baseState.IsSaved = true;
    baseState.AuthorPersonID = 'P-AUTHOR';
    baseState.AuthorEmail = 'author@example.com';
  });

  it('rejects any change to AuthorPersonID', async () => {
    fieldInfo['AuthorPersonID'] = { Dirty: true, OldValue: 'P-AUTHOR' };
    await expect(new IssueCommentEntityServer().Save()).rejects.toThrow(/immutable/);
    expect(baseSaveMock).not.toHaveBeenCalled();
  });

  it('rejects any change to AuthorEmail', async () => {
    fieldInfo['AuthorEmail'] = { Dirty: true, OldValue: 'author@example.com' };
    await expect(new IssueCommentEntityServer().Save()).rejects.toThrow(/immutable/);
    expect(baseSaveMock).not.toHaveBeenCalled();
  });

  it('rejects a Body edit when the context user is not the author', async () => {
    fieldInfo['Body'] = { Dirty: true, OldValue: 'hello' };
    peopleRows = [{ ID: 'P-SOMEONE-ELSE', LinkedUserID: 'U-1', Email: 'user@example.com' }];
    await expect(new IssueCommentEntityServer().Save()).rejects.toThrow(/only the comment's author/);
    expect(baseSaveMock).not.toHaveBeenCalled();
  });

  it('rejects a Source or IssueID edit when the context user is not the author', async () => {
    fieldInfo['Source'] = { Dirty: true, OldValue: 'internal' };
    peopleRows = [{ ID: 'P-SOMEONE-ELSE', LinkedUserID: 'U-1', Email: 'user@example.com' }];
    await expect(new IssueCommentEntityServer().Save()).rejects.toThrow(/only the comment's author/);
    expect(baseSaveMock).not.toHaveBeenCalled();
  });

  it('allows a Body edit when the context user maps to the author Person', async () => {
    fieldInfo['Body'] = { Dirty: true, OldValue: 'hello' };
    peopleRows = [{ ID: 'p-author', LinkedUserID: 'U-1', Email: 'user@example.com' }]; // case-insensitive UUID match
    const ok = await new IssueCommentEntityServer().Save();
    expect(ok).toBe(true);
    expect(baseSaveMock).toHaveBeenCalledOnce();
  });

  it('matches personless (email-only) authors on the authenticated email', async () => {
    baseState.AuthorPersonID = null;
    baseState.AuthorEmail = 'User@Example.com';
    fieldInfo['Body'] = { Dirty: true, OldValue: 'hello' };
    const ok = await new IssueCommentEntityServer().Save();
    expect(ok).toBe(true);
  });

  it('rejects edits to a personless comment when both emails are empty/whitespace', async () => {
    baseState.AuthorPersonID = null;
    baseState.AuthorEmail = '   ';
    baseState.ContextCurrentUser = { ID: 'U-2', Email: '   ' };
    fieldInfo['Body'] = { Dirty: true, OldValue: 'hello' };
    await expect(new IssueCommentEntityServer().Save()).rejects.toThrow(/only the comment's author/);
    expect(baseSaveMock).not.toHaveBeenCalled();
  });

  it('lets non-content updates through without an author check', async () => {
    const ok = await new IssueCommentEntityServer().Save();
    expect(ok).toBe(true);
    expect(runViewMock).not.toHaveBeenCalled();
  });

  it('rejects a content edit when there is no context user', async () => {
    baseState.ContextCurrentUser = undefined;
    fieldInfo['Body'] = { Dirty: true, OldValue: 'hello' };
    await expect(new IssueCommentEntityServer().Save()).rejects.toThrow(/only the comment's author/);
  });
});
