'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { FINAL_REMINDER_MARKER, INITIAL_REMINDER_MARKER, lifecycle, messages, readiness, qualifyingActivity, selectReadinessRun } = require('./policy');

const repo = 'bullbitcoin/bull';
const issue = (number, state = 'OPEN', labels = ['ready']) => ({ number, state, labels, repository: { nameWithOwner: repo } });
const base = (overrides = {}) => ({ repository: { nameWithOwner: repo }, labels: [], author: { login: 'contributor' }, closingIssuesReferences: [], ...overrides });
const iso = (days) => new Date(Date.UTC(2026, 0, 1 + days)).toISOString();
const life = (days, extra = {}) => lifecycle({ now: iso(90), lastActivityAt: iso(90 - days), comments: [], events: [], ...extra });
const comment = (marker, days, user = 'github-actions[bot]') => ({ body: marker, created_at: iso(days), user: { login: user, type: 'Bot' } });

test('readiness accepts one local open ready closing issue', () => assert.equal(readiness(base({ closingIssuesReferences: [issue(1)] })).ready, true));
test('readiness accepts GraphQL label connections', () => {
  const graphqlIssue = { ...issue(1), labels: { nodes: [{ name: 'ready' }] } };
  const graphqlPr = base({ labels: { nodes: [] }, closingIssuesReferences: [graphqlIssue] });
  assert.equal(readiness(graphqlPr).ready, true);
});
test('readiness rejects invalid issue references', () => {
  for (const refs of [[], [issue(1, 'OPEN', [])], [issue(1, 'CLOSED')], [issue(1), issue(2, 'CLOSED')]]) assert.equal(readiness(base({ closingIssuesReferences: refs })).ready, false);
  assert.equal(readiness(base({ closingIssuesReferences: [{ ...issue(1), repository: { nameWithOwner: 'other/project' } }] })).ready, false);
});
test('dependabot and no-issue-needed are exempt', () => {
  assert.equal(readiness(base({ author: { login: 'dependabot[bot]' } })).exempt, true);
  assert.equal(readiness(base({ labels: ['no-issue-needed'] })).exempt, true);
});
test('run selection requires current PR SHA and readiness metadata', () => {
  const current = { id: 2, status: 'completed', head_sha: 'current', created_at: '2026-01-02T00:00:00Z', pull_requests: [{ number: 7 }] };
  const otherPr = { ...current, id: 3, pull_requests: [{ number: 8 }] };
  const inProgress = { ...current, id: 4, status: 'in_progress' };
  assert.equal(selectReadinessRun([{ ...current, id: 1, head_sha: 'old' }, otherPr, inProgress, current], 7, 'current'), current);
  assert.equal(selectReadinessRun([{ ...current, head_sha: 'old' }], 7, 'current'), null);
  assert.equal(selectReadinessRun([otherPr], 7, 'current'), null);
  assert.equal(selectReadinessRun([inProgress], 7, 'current'), null);
});

test('normal timeline is none at J74, initial at J75, final at J83, and close at J90', () => {
  assert.equal(life(74).action, 'none');
  assert.equal(life(75).action, 'remind');
  const initial = comment(INITIAL_REMINDER_MARKER, 75);
  assert.equal(lifecycle({ now: iso(82), lastActivityAt: iso(0), comments: [initial], events: [] }).action, 'none');
  assert.equal(lifecycle({ now: iso(83), lastActivityAt: iso(0), comments: [initial], events: [] }).action, 'final-reminder');
  const both = [initial, comment(FINAL_REMINDER_MARKER, 83)];
  assert.equal(lifecycle({ now: iso(89), lastActivityAt: iso(0), comments: both, events: [] }).action, 'none');
  assert.equal(lifecycle({ now: iso(90), lastActivityAt: iso(0), comments: both, events: [] }).action, 'close');
});
test('closure requires both reminders', () => {
  assert.equal(life(90).action, 'remind');
  assert.equal(lifecycle({ now: iso(90), lastActivityAt: iso(0), comments: [comment(INITIAL_REMINDER_MARKER, 75)], events: [] }).action, 'final-reminder');
});
test('late final reminder delays closure by seven real days', () => {
  const comments = [comment(INITIAL_REMINDER_MARKER, 75), comment(FINAL_REMINDER_MARKER, 86)];
  assert.equal(lifecycle({ now: iso(90), lastActivityAt: iso(0), comments, events: [] }).action, 'none');
  assert.equal(lifecycle({ now: iso(93), lastActivityAt: iso(0), comments, events: [] }).action, 'close');
});
test('late initial reminder shifts final and closure', () => {
  const initial = comment(INITIAL_REMINDER_MARKER, 80);
  assert.equal(lifecycle({ now: iso(87), lastActivityAt: iso(0), comments: [initial], events: [] }).action, 'none');
  assert.equal(lifecycle({ now: iso(88), lastActivityAt: iso(0), comments: [initial], events: [] }).action, 'final-reminder');
  assert.equal(lifecycle({ now: iso(94), lastActivityAt: iso(0), comments: [initial, comment(FINAL_REMINDER_MARKER, 88)], events: [] }).action, 'none');
  assert.equal(lifecycle({ now: iso(95), lastActivityAt: iso(0), comments: [initial, comment(FINAL_REMINDER_MARKER, 88)], events: [] }).action, 'close');
});
test('a human event starts a fresh cycle even when it remains in the timeline', () => {
  const comments = [comment(INITIAL_REMINDER_MARKER, 75), comment(FINAL_REMINDER_MARKER, 83)];
  const event = { type: 'comment', actorType: 'User', at: iso(76), body: 'still working' };
  assert.equal(lifecycle({ now: iso(76), lastActivityAt: iso(0), comments, events: [event] }).action, 'reset-label');
  assert.equal(lifecycle({ now: iso(151), lastActivityAt: iso(0), comments, events: [event] }).action, 'remind');
});
test('final marker before current initial marker is ignored', () => {
  const comments = [comment(FINAL_REMINDER_MARKER, 82), comment(INITIAL_REMINDER_MARKER, 83)];
  assert.equal(lifecycle({ now: iso(90), lastActivityAt: iso(0), comments, events: [] }).action, 'none');
  assert.equal(lifecycle({ now: iso(91), lastActivityAt: iso(0), comments, events: [] }).action, 'final-reminder');
});
test('human activity after either reminder resets, while bot activity does not', () => {
  const comments = [comment(INITIAL_REMINDER_MARKER, 75), comment(FINAL_REMINDER_MARKER, 83)];
  for (const at of [76, 84]) assert.equal(lifecycle({ now: iso(90), lastActivityAt: iso(0), comments, events: [{ type: 'comment', actorType: 'User', at: iso(at) }] }).action, 'reset-label');
  assert.equal(lifecycle({ now: iso(90), lastActivityAt: iso(84), comments, events: [{ type: 'comment', actorType: 'User', at: iso(84) }] }).action, 'reset-label');
  assert.equal(lifecycle({ now: iso(90), lastActivityAt: iso(0), comments, events: [{ type: 'comment', actorType: 'Bot', at: iso(84) }] }).action, 'close');
});
test('arbitrary human comments qualify regardless of body', () => {
  assert.equal(qualifyingActivity({ type: 'comment', actorType: 'User', body: 'Any wording at all' }), true);
  assert.equal(qualifyingActivity({ type: 'comment', actorType: 'Bot', body: 'bump' }), false);
});
test('push, review, edits, ready, and reopen activity remain qualifying', () => {
  for (const type of ['push', 'synchronize', 'review', 'title-edit', 'body-edit', 'ready-label', 'reopen-pr', 'reopen-issue']) assert.equal(qualifyingActivity({ type, actorType: 'User' }), true);
});
test('forged, future, invalid, and body timestamps are ignored', () => {
  const comments = [comment(INITIAL_REMINDER_MARKER, 75), comment(FINAL_REMINDER_MARKER, 83, 'contributor'), comment(FINAL_REMINDER_MARKER, 83, 'github-actions[bot]'), comment(FINAL_REMINDER_MARKER, 91), comment(FINAL_REMINDER_MARKER, 83)];
  comments[2].user.type = 'User';
  comments[4].created_at = 'not-a-date';
  comments[0].body += ' claimed at 2099-01-01T00:00:00Z';
  assert.equal(lifecycle({ now: iso(90), lastActivityAt: iso(0), comments, events: [] }).action, 'final-reminder');
});
test('qualifying activity and messages retain positive lifecycle language', () => {
  assert.equal(qualifyingActivity({ type: 'comment', actorType: 'User' }), true);
  assert.equal(qualifyingActivity({ type: 'comment', actorType: 'Bot' }), false);
  const text = messages['final-reminder']('url');
  for (const phrase of ['Thank you', 'still inactive', '7 days', 'human comment', 'resumed work', 'maintainers', 'not rejection', 'reopening']) assert.match(text, new RegExp(phrase, 'i'));
  assert.match(messages.reminder('url'), /scheduled to close in 15 days/i);
});
test('incomplete API metadata never closes', () => assert.equal(lifecycle({ now: iso(90), lastActivityAt: iso(0), comments: [], events: undefined }).action, 'none'));
test('future and invalid human events cannot accelerate closure', () => {
  const comments = [comment(INITIAL_REMINDER_MARKER, 75), comment(FINAL_REMINDER_MARKER, 83)];
  const events = [{ type: 'comment', actorType: 'User', at: iso(200) }, { type: 'comment', actorType: 'User', at: 'not-a-date' }];
  assert.equal(lifecycle({ now: iso(90), lastActivityAt: iso(0), comments, events }).action, 'close');
});
test('closed or reopened PR state does not receive lifecycle actions', () => {
  assert.equal(life(90, { open: false }).action, 'none');
});
