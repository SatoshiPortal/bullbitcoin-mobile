---
name: Use Makefile for build commands
description: Project has a makefile with standard targets - prefer these over raw flutter/dart commands
type: feedback
---

Use `make <target>` instead of raw flutter/dart commands where a target exists.

Key targets:
- `make deps` → `fvm flutter pub get`
- `make build-runner` → `fvm dart run build_runner build --delete-conflicting-outputs`
- `make unit-test` → `fvm flutter test test/ --reporter=compact`
- `make test` → runs both unit and integration tests

The project uses `fvm` (Flutter Version Manager), so commands go through `fvm flutter` / `fvm dart`.

**Why:** The user reminded us the makefile exists — use it to stay consistent with the project's tooling conventions.

**How to apply:** When running pub get, build_runner, or tests, check makefile first.
