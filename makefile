.PHONY: workspace-graph workspace-graph-check rust-bindings-codegen onion-codegen onion-device-test bitbox-device-test native-write-check secrets-api-docs secrets-api-docs-check sync-api-docs sync-api-docs-check custody-check custody-ci-check all setup clean deps deps-update bootstrap analyze build-runner translations hooks ios-simulator ios-release drift-migrations devcontainer devcontainer-up container-tools container-app android release debug beta verify verify-rustc-pins rust-versions rustc-pins-test aot-check unit-test-shard-test action-pins-check pr-governance-ci-test test unit-test integration-test catalogue fvm-check

fvm-check:
	@echo "🔍 Checking FVM"
	@if ! command -v fvm >/dev/null 2>&1; then \
		echo "❌ FVM is not installed. Please install FVM first:"; \
		exit 1; \
	fi
	@echo "✅ FVM is installed"
	@fvm install

all: setup
	@echo "✨ All tasks completed!"

setup: fvm-check clean deps build-runner translations hooks
	@if [ "$$(uname)" = "Darwin" ]; then fvm flutter precache --ios; fi
	@echo "🚀 Setup complete!"

clean:
	@echo "🧹 Clean build artifacts (keeps lockfiles)"
	@fvm flutter clean

deps:
	@echo "🏃 Fetch dependencies (enforce pubspec.lock)"
	@fvm flutter pub get --enforce-lockfile

# Intentionally re-resolve from scratch: deletes the lockfiles and lets pub pick
# fresh versions (and, for branch refs, fresh commits). Use only when you mean to
# update dependencies, then commit the regenerated pubspec.lock.
deps-update:
	@echo "🔓 Re-resolving dependencies (deletes pubspec.lock)"
	@rm -f pubspec.lock
	@fvm flutter pub get

# Melos workspace bootstrap (pub get across the workspace + package linking).
# Wraps `fvm dart run melos` so the pinned SDK (.fvmrc) is used — never bare
# `melos`. Single root package today (useRootAsPackage), so this is ~equivalent
# to `make deps`; it becomes meaningful once packages/ + features/ gain members.
bootstrap:
	@echo "🧩 Melos bootstrap"
	@fvm dart run melos bootstrap

analyze:
	@echo "🔍 Analyze whole project (matches CI: --fatal-warnings --fatal-infos)"
	@fvm flutter analyze --fatal-warnings --fatal-infos

# Local Dart/Flutter gates. CI also runs the Node-based custody import and PR governance checks; Node is not required for `make checks`. The pre-commit hook deliberately does NOT call fix-check/format-check: it runs its own staged-only variants in parallel with `make analyze` for speed.
fix-check:
	@echo "🧹 dart fix should have nothing to suggest"
	@bash -c 'set -o pipefail; fvm dart fix --dry-run | tee /dev/stderr | grep -q "Nothing to fix!"'

# Formatting gate scoped to existing git-tracked source via git ls-files: untracked generated code never trips it, deleted files are skipped, and tracked generated files are filtered by suffix and by /generated/ path segment because `dart format` does not read analysis_options.yaml `exclude:`. Keep the regex in sync with the staged-files variant in .git_hooks/pre-commit. pipefail so a git/grep failure cannot silently pass the gate (xargs -r would no-op and exit 0), and bounded batches keep the formatter below ARG_MAX as the workspace grows.
format-check:
	@echo "🎨 dart format should have nothing to change"
	@bash -c 'set -o pipefail; git ls-files "*.dart" | grep -vE "\.(g|freezed|gr|config|mocks|steps)\.dart$$|/generated/" | while IFS= read -r file; do if [ -f "$$file" ]; then printf "%s\n" "$$file"; fi; done | xargs -r -n 100 fvm dart format --output=none --set-exit-if-changed'

# The only typed-in font sizes outside BullTypography.standard: the Bebas Neue brand wordmarks, sized by their splash layout and marked "Brand wordmark" at the call site.
FONT_SIZE_ALLOWLIST := ^(lib/features/onboarding/ui/screens/onboarding_splash|features/wizard/lib/src/ui/widgets/welcome_step|features/bull_exchange/lib/src/ui/screens/exchange_landing_screen(_v2)?)\.dart:[0-9]+: *fontSize: [0-9]+, // Brand wordmark
BULL_KEYPAD_FILES := packages/bull_ui/lib/src/inputs/bull_keypad.dart packages/bull_ui/lib/src/inputs/bull_mnemonic_keyboard.dart packages/bull_ui/lib/src/inputs/bull_pin_pad.dart

bull-ui-check: typography-check
	@echo "🧱 bull_ui import boundary (coins/ui imports only package:bull_ui)"
	@if grep -rEl "package:(flutter/(material|cupertino|widgets)|material_ui/material_ui|cupertino_ui/cupertino_ui)\.dart" lib/features/coins/ui; then echo "lib/features/coins/ui must import only package:bull_ui/bull_ui.dart, not Flutter UI directly"; exit 1; fi
	@echo "🧱 corner radius roles (widgets read context.bullShapes, never a typed-in radius)"
	@if grep -rnE "Radius\.circular\( *[0-9]" lib features packages --include='*.dart' | grep -v "/test/" | grep -v "^packages/bull_ui/lib/src/theme/app_theme.dart:"; then echo "Read a corner radius from context.bullShapes.<role>; the numbers live only in BullShapes.standard"; exit 1; fi
	@echo "🧱 text sizes (typography roles, never a typed-in font size)"
	@if grep -rnE "fontSize:[^,;]*([^A-Za-z0-9_.]|^)[0-9]+(\.[0-9]+)?([^A-Za-z0-9_]|$$)" lib features packages --include='*.dart' | grep -v "/test/" | grep -v "^packages/bull_ui/lib/src/theme/bull_typography.dart:" | grep -vE "$(FONT_SIZE_ALLOWLIST)"; then echo "Read a text size from context.bullType.<role> (or BullText(role: ...)), changing only its weight or colour; size a keypad glyph from BullKeypadMetrics.glyphSize. The numbers live only in BullTypography.standard"; exit 1; fi
	@if grep -rnE "fontSize: *$$" lib features packages --include='*.dart' | grep -v "/test/"; then echo "Keep a fontSize on one line so the typed-in size check can read it"; exit 1; fi
	@echo "🧱 keypad colours (BullKeypadColors, never a typed-in colour)"
	@if grep -n "Color(0x" $(BULL_KEYPAD_FILES); then echo "Read a keypad colour from context.bullKeypad.<role>; the values live only in BullKeypadColors"; exit 1; fi

# Resolved-symbol custody policy, available locally with the pinned Dart SDK.
# Named exceptions cover exported swap child keys and public-only xpub decoding.
custody-check:
	@echo "🔒 custody key material: resolved Dart symbols"
	@fvm dart packages/secrets/tool/key_material_gate.dart

# Native stores have exactly one writer; readers and signers have scoped exceptions.
# BDK/LWK stay in packages/sync, plus a shrinking list of legacy files.
native-write-check:
	@fvm dart packages/sync/tool/native_write_gate.dart

# CI-only import/dependency/internal-seal policy, shared with PR custody review.
# Node is confined to these explicit CI targets, outside `make checks`.
custody-ci-check:
	@echo "🔒 custody imports and internal seal (CI only)"
	@node tools/pr_governance/custody-check.js

# The README's simplified public API trees are generated from resolved exports.
secrets-api-docs:
	@fvm dart packages/secrets/tool/api_docs.dart

secrets-api-docs-check:
	@fvm dart packages/secrets/tool/api_docs.dart --check

sync-api-docs:
	@fvm dart packages/sync/tool/api_docs.dart

sync-api-docs-check:
	@fvm dart packages/sync/tool/api_docs.dart --check

# WORKSPACE.md is the Melos dependency graph of the workspace members, generated
# so every migration commit shows the graph it produces.
WORKSPACE_GRAPH = { printf '%s\n\n%s\n\n%s\n' '\# Workspace graph' 'Generated by `make workspace-graph` from `fvm dart run melos list --mermaid`; do not edit by hand.' '```mermaid' && fvm dart run melos list --mermaid && printf '%s\n' '```'; }

workspace-graph:
	@$(WORKSPACE_GRAPH) > WORKSPACE.md

workspace-graph-check:
	@echo "🕸️ Checking WORKSPACE.md matches the Melos graph"
	@$(WORKSPACE_GRAPH) | diff -u WORKSPACE.md - || { echo "Run make workspace-graph and commit WORKSPACE.md"; exit 1; }

checks: app-icons-check workspace-graph-check analyze bull-ui-check native-write-check custody-check secrets-api-docs-check sync-api-docs-check fix-check format-check rustc-pins-test unit-test

# Supply-chain regression gate: every external GitHub Actions `uses:` reference
# must stay pinned to a full commit SHA (mutable tags can be repointed).
# Analyze and Test runs this as a dedicated lightweight job for every PR.
action-pins-check:
	@echo "📌 Checking GitHub Actions are pinned to a commit SHA"
	@bash tools/check_action_pins.sh

pr-governance-ci-test:
	@echo "🛡️ Testing PR governance and custody policy (CI only)"
	@node --test tools/pr_governance/policy.test.js tools/pr_governance/custody.test.js

# Regenerate the flutter_rust_bridge bindings after changing a Rust API. Needs
# flutter_rust_bridge_codegen 2.13.0, the Flutter of .fvmrc on PATH and libclang
# (LLVM_PATH=<llvm dir> when it is not found). Commit the output on its own.
rust-bindings-codegen:
	@bash packages/rust_bindings/codegen.sh $(if $(LLVM_PATH),--llvm-path $(LLVM_PATH))

onion-codegen:
	@bash packages/onion/codegen.sh $(if $(LLVM_PATH),--llvm-path $(LLVM_PATH))

# Table-owner package paths in dependency order. Add an owner here when its
# tables leave the app; its modular outputs must exist before the composer runs.
DRIFT_OWNER_PACKAGES := packages/legacy_storage packages/secrets packages/electrum packages/mempool packages/labels packages/preferences
