# Contributing

## Issue first

Start with a bug report or feature request before opening implementation work. Maintainers and triagers apply the single `ready` label when an issue is ready for implementation by any contributor; contributors should not apply it themselves. An issue can be discussed and refined before it becomes ready.

A pull request must use a GitHub-recognized closing reference such as `Closes #123` for at least one open local issue labelled `ready`. Every local issue the pull request claims to close must remain open and carry `ready`. The `no-issue-needed` pull request label is an exemption, as are Dependabot pull requests. Do not apply `ready` automatically from an issue form.

The PR readiness workflow is introduced here, but it is not a required check until a repository administrator validates it with local and fork fixtures and activates the rule. The `PR readiness` check is intentionally distinct from application `CI`. The target ruleset requires these two checks without mandatory approvals or CODEOWNERS; maintainers must therefore inspect any pull request that changes the workflows producing those checks.

## Positive stale lifecycle

All pull requests, including drafts, receive a friendly initial reminder after 75 days without qualifying human activity and a second positive reminder seven days before closure. Normally these occur at 75, 83, and 90 days. Closure is due at the later of 90 days after the last human activity or 15 days after the server timestamp of the initial reminder; the final reminder is due seven days before that, and a late final reminder moves closure to at least seven days afterward. Closure requires both trusted reminders. Comments on the pull request or a linked issue, pushes, submitted reviews, human title or body edits, applying `ready`, and reopening reset the lifecycle; bot activity does not.

This is queue maintenance, not rejection. Any new human comment resets the lifecycle regardless of its wording; “bump” is only an example. Contributors are invited to mention project maintainers on the issue for triage or prioritization. A closed pull request can always be reopened when the work is ready. Missing or uncertain API data never authorizes closure.

## Security

Never put mnemonics, private keys, PINs, tokens, or other secrets in issues, pull requests, logs, or fixtures. Report vulnerabilities privately through the [Security Policy](SECURITY.md).
