'use strict';

const READY = 'ready';

function labelsOf(pr) {
  return new Set((pr.labels || []).map((label) => typeof label === 'string' ? label : label.name));
}

function readiness(pr) {
  const labels = labelsOf(pr);
  if (labels.has('no-issue-needed') || pr.author?.login === 'dependabot[bot]') {
    return { exempt: true, ready: true, reason: 'exempt' };
  }
  const refs = pr.closingIssuesReferences || [];
  const local = refs.filter((issue) => issue.repository?.nameWithOwner === pr.repository?.nameWithOwner);
  const invalid = local.filter((issue) => issue.state !== 'OPEN' || !labelsOf(issue).has(READY));
  if (local.length > 0 && invalid.length === 0) {
    return { exempt: false, ready: true, reason: 'ready-issue' };
  }
  return { exempt: false, ready: false, reason: refs.length === 0 ? 'no-closing-issue' : 'issue-not-ready' };
}

function selectReadinessRun(runs, pullRequestNumber, headSha) {
  return (runs || []).filter((run) => run.status === 'completed' && run.head_sha === headSha && run.pull_requests?.some((pr) => pr.number === pullRequestNumber)).sort((a, b) => new Date(b.created_at) - new Date(a.created_at))[0] || null;
}

const INITIAL_REMINDER_MARKER = '<!-- bull-stale-initial-reminder:v1 -->';
const FINAL_REMINDER_MARKER = '<!-- bull-stale-final-reminder:v1 -->';

function human(event) {
  return event.actorType === 'User';
}

function qualifyingActivity(event) {
  return human(event) && ['comment', 'issue-comment', 'push', 'synchronize', 'review', 'title-edit', 'body-edit', 'ready-label', 'reopen-pr', 'reopen-issue'].includes(event.type);
}

function markerTimestamp(comments, marker, now) {
  const nowMs = Date.parse(now);
  const matches = (comments || []).flatMap((comment) => {
    const trusted = comment.user?.login === 'github-actions[bot]' && (!comment.user.type || comment.user.type === 'Bot');
    const timestamp = Date.parse(comment.created_at);
    return trusted && String(comment.body || '').includes(marker) && Number.isFinite(timestamp) && (!Number.isFinite(nowMs) || timestamp <= nowMs) ? [timestamp] : [];
  });
  return matches.length ? Math.max(...matches) : null;
}

function reminderTimestamp(comments, now) {
  return markerTimestamp(comments, INITIAL_REMINDER_MARKER, now);
}

function lifecycle({ now, lastActivityAt, comments, events, open = true }) {
  if (!open) return { action: 'none', reason: 'reopened-or-closed' };
  if (!Array.isArray(comments) || !Array.isArray(events)) return { action: 'none', reason: 'incomplete-metadata' };
  const nowMs = Date.parse(now);
  const suppliedActivityMs = Date.parse(lastActivityAt);
  const eventActivityMs = events.map((event) => {
    const eventMs = Date.parse(event.at);
    return qualifyingActivity(event) && Number.isFinite(eventMs) && eventMs <= nowMs ? eventMs : null;
  }).filter((value) => value !== null);
  const activityCandidates = [Number.isFinite(suppliedActivityMs) && suppliedActivityMs <= nowMs ? suppliedActivityMs : null, ...eventActivityMs].filter((value) => value !== null);
  if (!Number.isFinite(nowMs) || activityCandidates.length === 0) return { action: 'none', reason: 'missing-date' };
  const activityMs = Math.max(...activityCandidates);
  const age = nowMs - activityMs;
  const day = 24 * 60 * 60 * 1000;
  const recordedInitial = markerTimestamp(comments, INITIAL_REMINDER_MARKER, now);
  const recordedFinal = markerTimestamp(comments, FINAL_REMINDER_MARKER, now);
  const initialReminder = recordedInitial !== null && recordedInitial >= activityMs ? recordedInitial : null;
  const finalReminder = recordedFinal !== null && initialReminder !== null && recordedFinal >= activityMs && recordedFinal >= initialReminder ? recordedFinal : null;
  const reminderBoundary = Math.min(...[recordedInitial, recordedFinal].filter((value) => value !== null));
  const hasActivityAfterReminder = Number.isFinite(reminderBoundary) && eventActivityMs.some((eventMs) => eventMs > reminderBoundary);
  const oldMarker = [recordedInitial, recordedFinal].some((value) => value !== null && value < activityMs);
  if (oldMarker && hasActivityAfterReminder && age < 75 * day) return { action: 'reset-label', reason: 'activity-after-reminder' };
  if (initialReminder === null) {
    if (age >= 75 * day) return { action: 'remind' };
    return { action: 'none', reason: 'not-due' };
  }
  const closureDue = Math.max(activityMs + 90 * day, initialReminder + 15 * day);
  const finalDue = closureDue - 7 * day;
  if (finalReminder === null && nowMs >= finalDue) return { action: 'final-reminder', initialReminderAt: new Date(initialReminder).toISOString() };
  const closeDue = finalReminder === null ? Infinity : Math.max(closureDue, finalReminder + 7 * day);
  if (finalReminder !== null && nowMs >= closeDue) {
    return { action: 'close', initialReminderAt: new Date(initialReminder).toISOString(), finalReminderAt: new Date(finalReminder).toISOString() };
  }
  return { action: 'none', reason: 'not-due' };
}

const messages = {
  reminder: (url) => `Thank you for keeping this contribution moving! This PR has been quiet for 75 days and is scheduled to close in 15 days if there is no new human activity. Anyone can comment with an update or a question; please mention the project maintainers on the linked issue if you would like help with triage or prioritization. This is a friendly queue-maintenance reminder, not a rejection. If the work is ready later, the PR can always be reopened.\n\n${url}\n${INITIAL_REMINDER_MARKER}`,
  'final-reminder': (url) => `Thank you for your contribution. This PR is still inactive and is scheduled to close in 7 days. Any human comment or resumed work keeps it open; please mention the project maintainers on the linked issue if you would like help with triage or prioritization. Closure is queue maintenance, not rejection, and reopening remains possible when the work is ready.\n\n${url}\n${FINAL_REMINDER_MARKER}`,
  closure: (url) => `Thank you for the contribution. We are closing this PR after 90 days without qualifying human activity to keep the queue maintainable. This is queue maintenance, not a rejection: anyone can comment, and you can always reopen the PR when you are ready. Please mention the project maintainers on the linked issue if you would like help with triage or prioritization.\n\n${url}`,
};

module.exports = { READY, INITIAL_REMINDER_MARKER, FINAL_REMINDER_MARKER, readiness, lifecycle, qualifyingActivity, reminderTimestamp, selectReadinessRun, messages };
