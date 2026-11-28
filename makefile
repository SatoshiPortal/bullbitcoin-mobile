.PHONY: regtest-hosted-check workspace-graph workspace-graph-check rust-bindings-codegen onion-codegen onion-device-test bitbox-device-test native-write-check secrets-api-docs secrets-api-docs-check sync-api-docs sync-api-docs-check custody-check custody-ci-check all setup clean deps deps-update bootstrap analyze build-runner translations hooks ios-simulator ios-release drift-migrations devcontainer devcontainer-up container-tools container-app android release debug beta verify verify-rustc-pins rust-versions rustc-pins-test aot-check unit-test-shard-test action-pins-check pr-governance-ci-test test unit-test integration-test catalogue fvm-check

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
FONT_SIZE_ALLOWLIST := ^(features/onboarding/lib/src/ui/screens/onboarding_splash|features/wizard/lib/src/ui/widgets/welcome_step|features/bull_exchange/lib/src/ui/screens/exchange_landing_screen(_v2)?)\.dart:[0-9]+: *fontSize: [0-9]+, // Brand wordmark
BULL_KEYPAD_FILES := packages/bull_ui/lib/src/inputs/bull_keypad.dart packages/bull_ui/lib/src/inputs/bull_mnemonic_keyboard.dart packages/bull_ui/lib/src/inputs/bull_pin_pad.dart

bull-ui-check: typography-check
	@echo "🧱 bull_ui import boundary (coins/ui imports only package:bull_ui)"
	@if grep -rEl "package:(flutter/(material|cupertino|widgets)|material_ui/material_ui|cupertino_ui/cupertino_ui)\.dart" features/coins/lib/src/ui; then echo "features/coins/lib/src/ui must import only package:bull_ui/bull_ui.dart, not Flutter UI directly"; exit 1; fi
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
# RecoverBull backup preparation is confined to the inventory callback.
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

workspace-graph:
	@fvm dart tools/workspace_graph.dart

workspace-graph-check:
	@fvm dart tools/workspace_graph.dart --check

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

.PHONY: scuttle-codegen
scuttle-codegen:
	@bash packages/ark/codegen.sh $(if $(LLVM_PATH),--llvm-path $(LLVM_PATH))

# One build over every workspace member: build_runner resolves cross-package inputs (Drift owners before their composer, a member's types before its dependents) from the package graph, in a single process whose cache lives in the root .dart_tool/build.
build-runner:
	@echo "🏗️ Build runner for json_serializable and flutter_gen"
	@fvm dart run build_runner build --workspace --force-jit

.PHONY: btc-map-build-runner
btc-map-build-runner:
	@(cd features/btc_map && fvm dart run build_runner build --force-jit)

.PHONY: recoverbull-build-runner
recoverbull-build-runner:
	@(cd features/recoverbull && fvm dart run build_runner build --force-jit)

# One workspace watcher by default, like build-runner. MEMBER=<path> watches that member alone, for example `make build-runner-watch MEMBER=features/coins`.
build-runner-watch:
	@echo "🏗️ Build runner for json_serializable and flutter_gen (watch mode)"
	@cd "$(if $(MEMBER),$(MEMBER),.)" && fvm dart run build_runner watch $(if $(MEMBER),,--workspace) --force-jit

# Flutter prints this configuration reminder for every catalog.
gen-l10n = bash -o pipefail -c 'fvm flutter gen-l10n | awk "$$1"' -- \
	'$$0 == "Because l10n.yaml exists, the options defined there will be used instead." { next } \
	 $$0 == "To use the command line arguments, delete the l10n.yaml file in the Flutter project." { skip_blank = 1; next } \
	 skip_blank && !NF { next } \
	 { skip_blank = 0; print }'

translations:
	@echo "🌐 Generating translations files"
	@$(MAKE) novlang-translations
	@$(gen-l10n)
	@(cd features/announcements && $(gen-l10n))
	@(cd features/views && $(gen-l10n))
	@(cd features/bitcoin_price && $(gen-l10n))
	@(cd features/btc_map && $(gen-l10n))
	@(cd features/bull_exchange && $(gen-l10n))
	@(cd features/logs && $(gen-l10n))
	@(cd features/quick_actions && $(gen-l10n))
	@(cd features/signers && $(gen-l10n))
	@(cd features/scanning && $(gen-l10n))
	@(cd features/mnemonic_entry && $(gen-l10n))
	@(cd features/backups && $(gen-l10n))
	@(cd features/backup_metadata && $(gen-l10n))
	@(cd features/access && $(gen-l10n))
	@(cd features/startup && $(gen-l10n))
	@(cd features/bip85 && $(gen-l10n))
	@(cd features/all_seed_view && $(gen-l10n))
	@(cd features/silent && $(gen-l10n))
	@(cd features/swap && $(gen-l10n))
	@(cd features/wallet_import && $(gen-l10n))
	@(cd features/transactions && $(gen-l10n))
	@(cd features/send && $(gen-l10n))
	@(cd features/address_view && $(gen-l10n))
	@(cd features/receive && $(gen-l10n))
	@(cd features/coins && $(gen-l10n))
	@(cd features/label_editor && $(gen-l10n))
	@(cd features/fees && $(gen-l10n))
	@(cd features/network && $(gen-l10n))
	@(cd features/settings && $(gen-l10n))
	@(cd features/wizard && $(gen-l10n))
	@(cd features/onboarding && $(gen-l10n))
	@(cd packages/notifications && $(gen-l10n))
	@$(MAKE) recoverbull-translations
	@$(MAKE) bull-ui-translations
	@$(MAKE) ark-translations
	@$(MAKE) novlang-bridge

.PHONY: ark-translations
ark-translations:
	@(cd features/ark && $(gen-l10n))

.PHONY: bull-ui-translations
bull-ui-translations:
	@(cd packages/bull_ui && $(gen-l10n))

.PHONY: novlang-translations
novlang-translations:
	@(cd packages/novlang && $(gen-l10n))

# Generates store-aware delegates from the novlang manifest and gen-l10n
# output for each catalogue. `dart <file>` on purpose: `dart run` would run
# the app's native build hooks.
.PHONY: novlang-bridge
novlang-bridge:
	@fvm dart tools/novlang_bridge.dart

.PHONY: recoverbull-translations
recoverbull-translations:
	@(cd features/recoverbull && $(gen-l10n))

hooks:
	@CURRENT_HOOKS_PATH=$$(git config --local core.hooksPath); \
	if [ "$$CURRENT_HOOKS_PATH" = ".git_hooks/" ]; then \
		echo "✅ Git hooks already configured"; \
	else \
		echo "🔧 Setting up git pre-commit hooks"; \
		git config --local core.hooksPath .git_hooks/; \
	fi

drift-migrations:
	@echo "🔄 Create schema and sum migrations"
	@(cd packages/legacy_storage && fvm dart run drift_dev make-migrations)
	fvm dart run drift_dev schema dump packages/swaps/lib/src/orders/data/order_swaps_database.dart packages/swaps/lib/src/orders/data/schemas/order_swaps_database/
	cd packages/bull_payjoin && fvm dart run drift_dev make-migrations
	@$(MAKE) recoverbull-drift-migrations
	@(cd features/announcements && fvm dart run drift_dev make-migrations)
	@(cd packages/swaps && fvm dart run drift_dev make-migrations)

.PHONY: secrets-multiview-test
# The multiple-view gate is a compile-time constant, so the suites that need it open run in their own invocation.
secrets-multiview-test:
	@(cd packages/secrets && fvm flutter test --dart-define=BULL_MULTI_VIEW=true test/view_*_test.dart test/last_view_test.dart test/supported_view_format_test.dart)
	@(cd packages/sync && fvm flutter test --enable-vmservice --dart-define=BULL_MULTI_VIEW=true test/secrets_wallet_catalog_test.dart)

.PHONY: secrets-drift-migrations
secrets-drift-migrations:
	@(cd packages/secrets && fvm dart run drift_dev make-migrations)

.PHONY: wallet-satellite-drift-migrations
wallet-satellite-drift-migrations:
	@(cd features/signers && fvm dart run drift_dev make-migrations)
	@(cd packages/sync && fvm dart run drift_dev make-migrations)

.PHONY: electrum-drift-migrations mempool-drift-migrations labels-drift-migrations
electrum-drift-migrations:
	@(cd packages/electrum && fvm dart run drift_dev make-migrations)

mempool-drift-migrations:
	@(cd packages/mempool && fvm dart run drift_dev make-migrations)

labels-drift-migrations:
	@(cd packages/labels && fvm dart run drift_dev make-migrations)

.PHONY: recoverbull-drift-migrations
recoverbull-drift-migrations:
	@(cd features/recoverbull && fvm dart run drift_dev make-migrations)

ios-simulator:
	@if [ "$$(uname)" != "Darwin" ]; then echo "iOS simulator builds require macOS"; exit 1; fi
	@case "$(BUILD_NUMBER)" in ''|*[!0-9]*|0) echo "BUILD_NUMBER must be a positive integer"; exit 1;; esac
	@echo "Building iOS Simulator app (build $(BUILD_NUMBER))"
# Flutter supports only debug mode on the iOS Simulator. Remove Android's
# default flavor temporarily because iOS has a single unflavored Runner scheme.
	@backup="$$(mktemp)"; cp pubspec.yaml "$$backup" \
	  && trap 'cp "$$backup" pubspec.yaml; rm -f "$$backup"' EXIT INT TERM \
	  && grep -v '^[[:space:]]*default-flavor:' "$$backup" > pubspec.yaml \
	  && fvm flutter build ios --simulator --debug --build-number "$(BUILD_NUMBER)"

ios-release:
	@if [ "$$(uname)" != "Darwin" ]; then echo "iOS releases require macOS"; exit 1; fi
	@case "$(BUILD_NUMBER)" in ''|*[!0-9]*|0) echo "BUILD_NUMBER must be a positive integer"; exit 1;; esac
	@echo "Building App Store IPA (build $(BUILD_NUMBER))"
# pubspec's `default-flavor: production` exists for the Android product flavors,
# but Flutter applies it to every platform: with no --flavor on the command line
# it still resolves one, then looks for a matching Xcode scheme. iOS ships a
# single unflavored Runner scheme, so the build aborts with a misleading "You
# must specify a --flavor option". Drop the key for the duration of the build and
# restore it whatever happens. The only visible effect is `appFlavor` being null
# instead of 'production', which the app reads in exactly one place, to draw the
# beta banner (lib/app.dart).
	@backup="$$(mktemp)"; cp pubspec.yaml "$$backup" \
	  && trap 'cp "$$backup" pubspec.yaml; rm -f "$$backup"' EXIT INT TERM \
	  && grep -v '^[[:space:]]*default-flavor:' "$$backup" > pubspec.yaml \
	  && fvm flutter build ipa --release --build-number "$(BUILD_NUMBER)" $(if $(EXPORT_OPTIONS_PLIST),--export-options-plist "$(EXPORT_OPTIONS_PLIST)")

# Container runtime — default podman, override with CONTAINER=docker for
# environments without podman.
CONTAINER ?= podman

# Pick the host-appropriate dev container config: macos on Darwin, linux
# elsewhere. The two differ only in host integration (GPU/X11/Rosetta); both
# build the same Containerfile.tools image. Override with
# `make devcontainer DEVCONTAINER_OS=linux|macos`. Recursively-expanded (=) so a
# command-line DEVCONTAINER_OS override flows into DEVCONTAINER_CONFIG/POSTSTART.
DEVCONTAINER_OS ?= $(if $(filter Darwin,$(shell uname)),macos,linux)
DEVCONTAINER_CONFIG = ./.devcontainer/$(DEVCONTAINER_OS)/devcontainer.json
# Container name is pinned to `bull` in both devcontainer.json runArgs (--name) —
# a static name so repeated opens / worktrees reuse one container instead of
# creating a per-folder one. Must stay in sync with that runArgs value.
DEVCONTAINER_NAME := bull
# The workspace mounts at /workspaces/<folder-basename> (devcontainer's
# localWorkspaceFolderBasename), independent of the container name above.
DEVCONTAINER_WORKDIR := /workspaces/$(notdir $(CURDIR))
# postStart lifecycle to replay when reusing an existing container: `devcontainer
# up` runs postStartCommand on create, but a plain `start` does not, and the
# session dbus + gnome-keyring daemons die on stop. Only linux bootstraps a
# keyring (macOS has none). The script is idempotent.
DEVCONTAINER_POSTSTART = $(if $(filter linux,$(DEVCONTAINER_OS)),.devcontainer/linux/init-keyring.sh,)

container-tools:
	@echo "🔧 Building tools image"
	@set -e; \
	flutter_version=$$(awk 'BEGIN{RS="";} { gsub(/\r/,""); s=$$0; sub(/.*"flutter"[[:space:]]*:[[:space:]]*"/,"",s); sub(/".*$$/,"",s); print s; exit }' .fvmrc); \
	jvm_target=$$(grep -E '^android\.jvmTarget=' android/gradle.properties | cut -d= -f2); \
	android_api=$$(grep -E '^android\.sdkPlatform=' android/gradle.properties | cut -d= -f2); \
	android_build_tools=$$(grep -E '^android\.buildToolsVersion=' android/gradle.properties | cut -d= -f2); \
	android_ndk=$$(grep -E '^android\.ndkVersion=' android/gradle.properties | cut -d= -f2); \
	for kv in "flutter (.fvmrc)=$$flutter_version" "android.jvmTarget=$$jvm_target" "android.sdkPlatform=$$android_api" "android.buildToolsVersion=$$android_build_tools" "android.ndkVersion=$$android_ndk"; do \
		if [ -z "$${kv#*=}" ]; then \
			echo "ERROR: $${kv%%=*} resolved empty — check .fvmrc / android/gradle.properties" >&2; \
			exit 1; \
		fi; \
	done; \
	$(CONTAINER) build -f Containerfile.tools -t bull-tools \
		--build-arg FLUTTER_VERSION=$$flutter_version \
		--build-arg RUST_VERSION=$(RUST_VERSION) \
		--build-arg JVM_TARGET=$$jvm_target \
		--build-arg ANDROID_API_LEVEL=$$android_api \
		--build-arg ANDROID_BUILD_TOOLS=$$android_build_tools \
		--build-arg ANDROID_NDK=$$android_ndk \
		--build-arg BDK_RUST_VERSION=$(BDK_RUST_VERSION) \
		--build-arg PAYJOIN_RUST_VERSION=$(PAYJOIN_RUST_VERSION) \
		$(if $(EXPECTED_RUST_VERSION),--build-arg EXPECTED_RUST_VERSION=$(EXPECTED_RUST_VERSION)) \
		.

container-app: container-tools
	@echo "📦 Building app image"
	@$(CONTAINER) build -f Containerfile.app -t bull-app \
		--build-arg GRADLE_HEAP=$(or $(GRADLE_HEAP),4g) \
		.

MODE ?= debug
FORMAT ?= apk
FLAVOR ?= production

# Allow "make android release", "make android debug" or "make android beta".
# release/debug build the production flavor; beta is the tester channel — the
# beta flavor (.beta applicationId, its own signing) in release mode, for direct
# store-less distribution.
ifneq (,$(filter release,$(MAKECMDGOALS)))
  MODE := release
endif
ifneq (,$(filter debug,$(MAKECMDGOALS)))
  MODE := debug
endif
ifneq (,$(filter beta,$(MAKECMDGOALS)))
  MODE := release
  FLAVOR := beta
endif
release debug beta:
	@:

# Gradle appbundle output dir is camelCase <flavor><BuildType> (e.g. productionRelease).
MODE_CAP := $(if $(filter release,$(MODE)),Release,Debug)

# Host artifact name reflects the build target: BULL-release / BULL-debug for the
# production flavor, and BULL-<flavor> (e.g. BULL-beta) for channel flavors. The
# in-container Flutter output keeps its app-<flavor>-<mode> names below; only the
# extracted host file is branded.
#
# Channel flavors (beta) are signed only when their key is present, mirroring the
# gradle signingConfig guard (android/key-beta.properties). With no key the build
# is unsigned — Flutter still names it app-<flavor>-<mode>.apk, so flag it -unsigned
# on the host so an uninstallable build is obvious. CI requires the key, so this
# only triggers for keyless local beta builds. Production names are left unbranded:
# release is intentionally unsigned in the reproducibility/verify flow and both CI
# upload and verify_build.sh depend on the exact BULL-release name.
ifeq ($(FLAVOR),production)
  HOST_NAME := $(MODE)
else ifeq (,$(wildcard android/key-beta.properties))
  HOST_NAME := $(FLAVOR)-unsigned
else
  HOST_NAME := $(FLAVOR)
endif

# Flutter writes APK and AAB to different, flavor-namespaced paths
ifeq ($(FORMAT),aab)
  CONTAINER_OUTPUT := /app/build/app/outputs/bundle/$(FLAVOR)$(MODE_CAP)/app-$(FLAVOR)-$(MODE).aab
  HOST_OUTPUT := ./BULL-$(HOST_NAME).aab
  FLUTTER_BUILD := fvm flutter build appbundle --$(MODE) --flavor $(FLAVOR)
else
  CONTAINER_OUTPUT := /app/build/app/outputs/flutter-apk/app-$(FLAVOR)-$(MODE).apk
  HOST_OUTPUT := ./BULL-$(HOST_NAME).apk
  # APKs ship arm64 only: no supported device needs the 32-bit or x86_64
  # libraries, and each extra ABI adds a full Rust and AOT compile. The AAB
  # keeps every ABI because Play serves each device its own split.
  FLUTTER_BUILD := fvm flutter build apk --$(MODE) --flavor $(FLAVOR) --target-platform android-arm64
endif

android: container-app
	@echo "🔨 Building $(FORMAT) ($(FLAVOR) $(MODE)) via $(CONTAINER)"
	@$(CONTAINER) rm -f bull-build > /dev/null 2>&1 || true
	@$(CONTAINER) run --name bull-build \
		--ulimit nofile=65536:65536 \
		bull-app bash -c '\
			SOURCE_DATE_EPOCH=$$(git -C /app log -1 --format=%ct) && \
			CARGO_ENCODED_RUSTFLAGS=$$(printf "%s\037%s\037%s" \
				"--remap-path-prefix=$$HOME/.cargo=/cargo" \
				"--remap-path-prefix=$$HOME/.rustup=/rustup" \
				"--remap-path-prefix=/app=/build") && \
			CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1 && \
			CARGO_NET_GIT_FETCH_WITH_CLI=true && \
			export SOURCE_DATE_EPOCH CARGO_ENCODED_RUSTFLAGS CARGO_PROFILE_RELEASE_CODEGEN_UNITS CARGO_NET_GIT_FETCH_WITH_CLI && \
			cd /app && \
			$(FLUTTER_BUILD)'
	@$(CONTAINER) cp bull-build:$(CONTAINER_OUTPUT) $(HOST_OUTPUT)
	@$(CONTAINER) rm bull-build > /dev/null
	@echo "✅ Output extracted: $(HOST_OUTPUT)"
	@sha256sum $(HOST_OUTPUT)
	@if [ "$(FORMAT)" = "apk" ]; then $(MAKE) --no-print-directory verify-rustc-pins APK=$(HOST_OUTPUT); fi

# Check every expected ABI and Rust library in the APK against the exact pinned
# compilers used by Native Assets. The shell verifier fails on missing ABI/lib,
# invalid archive, absent or conflicting compiler markers, and new Rust libs.
# APKs are arm64-only (see FLUTTER_BUILD above).
RUST_VERSION ?= 1.100.0
# Prevent rustup from installing unrelated declared targets during hook setup.
# Each hook still selects its own pinned compiler for the Cargo build.
export RUSTUP_TOOLCHAIN ?= $(RUST_VERSION)
export RUSTUP_AUTO_INSTALL ?= 0
BDK_RUST_VERSION ?= $(RUST_VERSION)
# Official hosted Payjoin pins this compiler explicitly in native/rust-toolchain.toml.
PAYJOIN_RUST_VERSION ?= 1.85.1
EXPECTED_ABIS ?= arm64-v8a
# The pinned Rust compilers as KEY=VALUE lines: CI loads them into $GITHUB_ENV so these variables stay their single source.
rust-versions:
	@echo RUST_VERSION=$(RUST_VERSION)
	@echo BDK_RUST_VERSION=$(BDK_RUST_VERSION)
	@echo PAYJOIN_RUST_VERSION=$(PAYJOIN_RUST_VERSION)
verify-rustc-pins:
	@set -e; \
	for version in $(RUST_VERSION) $(BDK_RUST_VERSION) $(PAYJOIN_RUST_VERSION); do \
		actual=$$($(CONTAINER) run --rm bull-app rustup run $$version rustc --version); \
		case "$$actual" in "rustc $$version ("*) ;; *) echo "Unexpected Rust compiler: $$actual" >&2; exit 1 ;; esac; \
	done; \
	bash tools/verify_rustc_pins.sh --require-scuttle "$(APK)" "$(RUST_VERSION)" "$(PAYJOIN_RUST_VERSION)" $(EXPECTED_ABIS)

rustc-pins-test:
	@python3 -m unittest tools.testing.test_verify_rustc_pins

unit-test-shard-test:
	@python3 -m unittest tools.testing.test_unit_test_shard

# Read-only reachability check of every hosted regtest endpoint the app uses.
regtest-hosted-check:
	@python3 -I tools/regtest/check_hosted.py tools/regtest/hosted.json

# Compile the app to a release AOT snapshot without the native build; catches Dart AOT compiler crashes that debug builds and tests miss. Needs generated code.
aot-check:
	@bash tools/aot_snapshot_check.sh

verify:
	@echo "🔍 Verifying reproducible build"
	@./reproducibility/verify_build.sh $(if $(VERSION),--version $(VERSION)) $(if $(APK),--apk $(APK))

# `make devcontainer` auto-detects the host OS (DEVCONTAINER_OS above); override
# with `make devcontainer DEVCONTAINER_OS=linux|macos`.
devcontainer: devcontainer-up

# Create the dev container only if one does not already exist; otherwise just
# (re)start the existing one and replay its postStart lifecycle — never recreate.
#
# No container-tools prerequisite: the devcontainer CLI builds its OWN image
# from Containerfile.tools with USERNAME=$USER. That ARG is set near the top of
# the Containerfile, so it cache-busts every layer relative to the bull-tools
# image (USERNAME=bull) — building container-tools first is wasted work, not a
# cache source. bull-tools stays a prerequisite of container-app/android only.
devcontainer-up:
	@if $(CONTAINER) container exists $(DEVCONTAINER_NAME) 2>/dev/null; then \
		echo "↻ $(DEVCONTAINER_NAME) already exists — starting it (not recreating)"; \
		$(CONTAINER) start $(DEVCONTAINER_NAME) >/dev/null; \
		if ! $(CONTAINER) exec $(DEVCONTAINER_NAME) test -d $(DEVCONTAINER_WORKDIR) 2>/dev/null; then \
			echo "✋ Container '$(DEVCONTAINER_NAME)' is bound to a different checkout ($(DEVCONTAINER_WORKDIR) is not mounted inside it)."; \
			echo "   The name is shared across clones/worktrees, so only one tree can use it at a time."; \
			echo "   Rebind to this checkout with: $(CONTAINER) rm -f $(DEVCONTAINER_NAME) && make devcontainer"; \
			exit 1; \
		fi; \
		if [ -n "$(DEVCONTAINER_POSTSTART)" ]; then \
			echo "  replaying postStart: $(DEVCONTAINER_POSTSTART)"; \
			$(CONTAINER) exec -w $(DEVCONTAINER_WORKDIR) $(DEVCONTAINER_NAME) $(DEVCONTAINER_POSTSTART); \
		fi; \
	else \
		echo "🏗️ Building Dev Container ($(DEVCONTAINER_OS))"; \
		devcontainer up --workspace-folder . --config $(DEVCONTAINER_CONFIG); \
	fi

test: unit-test integration-test

# One run per workspace member that has a test/ directory, each with its own tool, the app included (melos useRootAsPackage). melos iterates the declared `workspace:` list, not a directory glob, so a member added anywhere — features/ included — is tested without editing this target. `melos exec` is called directly through `fvm dart run`: `melos run` would re-invoke a bare `melos` from PATH, which the pinned SDK forbids. Fail-fast and one package at a time, like the loop it replaces.
# Optionally bound test processes inside each package on shared machines.
TEST_CONCURRENCY ?=
# TEST_TOTAL_SHARDS=N TEST_SHARD_INDEX=i runs one of N disjoint shards of every member's test files (tools/unit_test_shard.sh); CI runs the shards in parallel.
# TEST_PACKAGES=a,b limits a PR run to the live impacted selection. Empty keeps the full suite; the comma-separated value is one Melos scope glob.
TEST_TOTAL_SHARDS ?= 1
TEST_SHARD_INDEX ?= 0
TEST_PACKAGES ?=
MELOS_UNIT_TEST_SCOPE = $(if $(TEST_PACKAGES),--scope='$(TEST_PACKAGES)')
unit-test:
	@echo "🏃‍ running unit tests of $(if $(TEST_PACKAGES),impacted workspace members: $(TEST_PACKAGES),every workspace member)"
	@TEST_TOTAL_SHARDS=$(TEST_TOTAL_SHARDS) TEST_SHARD_INDEX=$(TEST_SHARD_INDEX) fvm dart run melos exec --flutter --dir-exists=test $(MELOS_UNIT_TEST_SCOPE) --concurrency 1 --fail-fast -- bash $(CURDIR)/tools/unit_test_shard.sh flutter --enable-vmservice --reporter=compact $(if $(TEST_CONCURRENCY),--concurrency $(TEST_CONCURRENCY))
	@TEST_TOTAL_SHARDS=$(TEST_TOTAL_SHARDS) TEST_SHARD_INDEX=$(TEST_SHARD_INDEX) fvm dart run melos exec --no-flutter --dir-exists=test $(MELOS_UNIT_TEST_SCOPE) --concurrency 1 --fail-fast -- bash $(CURDIR)/tools/unit_test_shard.sh dart --reporter=compact $(if $(TEST_CONCURRENCY),--concurrency $(TEST_CONCURRENCY))
	@if [ "$(TEST_SHARD_INDEX)" != 0 ]; then \
		echo "Skipping multiple-view tests: they run only in shard 0."; \
	elif [ -n "$(TEST_PACKAGES)" ] && ! printf ',%s,' "$(TEST_PACKAGES)" | grep -Eq ',(secrets|sync),'; then \
		echo "Skipping multiple-view tests: neither secrets nor sync is impacted."; \
	else \
		$(MAKE) secrets-multiview-test; \
	fi

# integration_test/all_test.dart is a single aggregator entrypoint: it runs
# Bull.init() once, then every test file's main(isInitialized: true). On the
# Linux desktop device the app can only be launched once per `flutter test`
# invocation, so running this one file builds + launches once for the whole
# suite (instead of failing every file but the first, as `flutter test
# integration_test/` does). all_test.dart is a generated, gitignored artifact —
# tools/gen_all_test.dart regenerates it from disk below. RecoverBull runs
# separately because its restore test changes the wallet inventory.
integration-test:
	@echo "🧪 integration tests"
	@fvm dart run tools/gen_all_test.dart
	@fvm flutter test integration_test/all_test.dart --reporter=expanded
	@bash tools/recoverbull_integration.sh

# Plugin integration tests that need hardware, outside `make integration-test`:
# onion's on a phone (Snowflake is mobile-only), bitbox_transport's on a phone
# with a BitBox02 attached over USB or reachable over BLE. DEVICE=<flutter device id>.
# The beta flavor installs beside the production app and leaves its data alone.
DEVICE_TEST_FLAVOR ?= beta

onion-device-test:
	@test -n "$(DEVICE)" || { echo "DEVICE=<id> is required" >&2; exit 1; }
	@fvm flutter test integration_test/onion --flavor $(DEVICE_TEST_FLAVOR) -d $(DEVICE) --timeout 5m

bitbox-device-test:
	@test -n "$(DEVICE)" || { echo "DEVICE=<id> is required" >&2; exit 1; }
	@fvm flutter test integration_test/bitbox_transport --flavor $(DEVICE_TEST_FLAVOR) -d $(DEVICE) --timeout 5m

# Physical-device credential probes use a separately installed debug APK.
# The SDK driver connects through VM_SERVICE_URL without installing an app.
.PHONY: exchange-credentials-device-build exchange-credentials-device-test
exchange-credentials-device-build:
	@fvm flutter build apk --debug --target-platform android-arm64 --split-per-abi --flavor production \
		--target integration_test/device/exchange_credentials_test.dart \
		--dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false

exchange-credentials-device-test:
	@test -n "$$VM_SERVICE_URL" || { echo "Set VM_SERVICE_URL to the running test app"; exit 1; }
	@fvm dart run integration_test/device/driver.dart

# Build & render the bull_ui design-system catalogue (Widgetbook) locally in the
# browser. Dev-only tooling — never shipped in the app. Regenerates the
# @UseCase directories, then runs the catalogue app on Chrome (hot-reload).
catalogue:
	@echo "📚 Building & rendering the bull_ui catalogue in the browser"
	@cd packages/bull_ui_catalogue && \
		fvm dart run build_runner build && \
		fvm flutter run -d chrome

# Keep the icon tool's cli_util separate from Melos, and resolve asset/output
# paths from the app root using the tool's explicit package configuration.
.PHONY: app-icons app-icons-deps app-icons-check
app-icons-deps:
	@fvm dart pub --directory=tools/app_icons get --enforce-lockfile

app-icons: app-icons-deps
	@fvm dart --packages=tools/app_icons/.dart_tool/package_config.json tools/app_icons/bin/generate.dart $(ICON_ARGS)

app-icons-check: app-icons-deps
	@cd tools/app_icons && fvm dart analyze --fatal-infos
	@fvm dart --packages=tools/app_icons/.dart_tool/package_config.json tools/app_icons/bin/generate.dart --help

.PHONY: typography-check
typography-check:
	@fvm dart tools/typography_roles.dart
