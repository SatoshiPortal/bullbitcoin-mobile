.PHONY: all setup clean deps deps-update bootstrap analyze build-runner translations hooks ios-pod-update drift-migrations devcontainer devcontainer-up container-tools container-app android release debug beta verify test unit-test integration-test catalogue fvm-check sp-analyze sp-audit sp-verify-all

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
	@if [ "$$(uname)" = "Darwin" ]; then $(MAKE) ios-pod-update; fi
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
	@echo "🔓 Re-resolving dependencies (deletes pubspec.lock + ios/Podfile.lock)"
	@rm -f pubspec.lock ios/Podfile.lock
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

# Check-only gates, one target per gate of the CI `checks` job in analyze_and_test.yml (which invokes these targets so each definition lives in exactly one place). `make checks` runs the whole job locally: green here means the checks job is green in CI. The pre-commit hook deliberately does NOT call fix-check/format-check: it runs its own staged-only variants in parallel with `make analyze` for speed.
fix-check:
	@echo "🧹 dart fix should have nothing to suggest"
	@bash -c 'set -o pipefail; fvm dart fix --dry-run | tee /dev/stderr | grep -q "Nothing to fix!"'

# Formatting gate scoped to git-tracked source via git ls-files: untracked generated code never trips it, and tracked generated files are filtered by suffix and by /generated/ path segment because `dart format` does not read analysis_options.yaml `exclude:`. Keep the regex in sync with the staged-files variant in .git_hooks/pre-commit. pipefail so a git/grep failure cannot silently pass the gate (xargs -r would no-op and exit 0).
format-check:
	@echo "🎨 dart format should have nothing to change"
	@bash -c 'set -o pipefail; git ls-files "*.dart" | grep -vE "\.(g|freezed|gr|config|mocks|steps)\.dart$$|/generated/" | xargs -r fvm dart format --output=none --set-exit-if-changed'

bull-ui-check:
	@echo "🧱 bull_ui import boundary (coins/ui imports only package:bull_ui)"
	@if grep -rEl "package:flutter/(material|cupertino|widgets)\.dart" lib/features/coins/ui; then echo "lib/features/coins/ui must import only package:bull_ui/bull_ui.dart, not Flutter UI directly"; exit 1; fi

checks: analyze bull-ui-check fix-check format-check unit-test

build-runner:
	@echo "🏗️ Build runner for json_serializable and flutter_gen"
	@fvm dart run build_runner build --force-jit --delete-conflicting-outputs

build-runner-watch:
	@echo "🏗️ Build runner for json_serializable and flutter_gen (watch mode)"
	@fvm dart run build_runner watch --delete-conflicting-outputs --force-jit

translations:
	@echo "🌐 Generating translations files"
	@fvm flutter gen-l10n

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
	fvm dart run drift_dev make-migrations

ios-pod-update:
	@if [ "$$(uname)" != "Darwin" ]; then echo "Skipping pod update (not macOS)"; exit 0; fi
	@echo "Fetching iOS dependencies"
	@fvm flutter precache --ios
	@cd ios && pod install --repo-update && cd -

ios-sqlite-update:
	@if [ "$$(uname)" != "Darwin" ]; then echo "Skipping pod update (not macOS)"; exit 0; fi
	@echo "Updating SQLite"
	@cd ios && pod update sqlite3 && cd -

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
	android_api=$$(grep -E '^android\.compileSdk=' android/gradle.properties | cut -d= -f2); \
	android_build_tools=$$(grep -E '^android\.buildToolsVersion=' android/gradle.properties | cut -d= -f2); \
	android_ndk=$$(grep -E '^android\.ndkVersion=' android/gradle.properties | cut -d= -f2); \
	for kv in "flutter (.fvmrc)=$$flutter_version" "android.jvmTarget=$$jvm_target" "android.compileSdk=$$android_api" "android.buildToolsVersion=$$android_build_tools" "android.ndkVersion=$$android_ndk"; do \
		if [ -z "$${kv#*=}" ]; then \
			echo "ERROR: $${kv%%=*} resolved empty — check .fvmrc / android/gradle.properties" >&2; \
			exit 1; \
		fi; \
	done; \
	$(CONTAINER) build -f Containerfile.tools -t bull-tools \
		--build-arg FLUTTER_VERSION=$$flutter_version \
		--build-arg JVM_TARGET=$$jvm_target \
		--build-arg ANDROID_API_LEVEL=$$android_api \
		--build-arg ANDROID_BUILD_TOOLS=$$android_build_tools \
		--build-arg ANDROID_NDK=$$android_ndk \
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
  FLUTTER_BUILD := fvm flutter build apk --$(MODE) --flavor $(FLAVOR)
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

unit-test:
	@echo "🏃‍ running unit tests"
	@fvm flutter test test/ --reporter=compact
	@for p in packages/*/; do \
		if [ -d "$${p}test" ]; then \
			echo "🏃‍ running $${p}test"; \
			( cd "$$p" && fvm flutter test --reporter=compact ); \
		fi; \
	done

# integration_test/all_test.dart is a single aggregator entrypoint: it runs
# Bull.init() once, then every test file's main(isInitialized: true). On the
# Linux desktop device the app can only be launched once per `flutter test`
# invocation, so running this one file builds + launches once for the whole
# suite (instead of failing every file but the first, as `flutter test
# integration_test/` does). all_test.dart is a generated, gitignored artifact —
# tools/gen_all_test.dart regenerates it from disk below, so adding a test file
# needs no manual wiring.
integration-test:
	@echo "🧪 integration tests"
	@fvm dart run tools/gen_all_test.dart
	@fvm flutter test integration_test/all_test.dart --reporter=expanded

# Build & render the bull_ui design-system catalogue (Widgetbook) locally in the
# browser. Dev-only tooling — never shipped in the app. Regenerates the
# @UseCase directories, then runs the catalogue app on Chrome (hot-reload).
catalogue:
	@echo "📚 Building & rendering the bull_ui catalogue in the browser"
	@cd packages/bull_ui_catalogue && \
		fvm dart run build_runner build --delete-conflicting-outputs && \
		fvm flutter run -d chrome

# Reuses the strict `analyze` target (--fatal-warnings --fatal-infos) so local SP
# analysis matches CI; build-runner first so generated sources exist.
sp-analyze: build-runner analyze

sp-audit:
	@echo "🔒 Running SP invariant audit"
	@bash scripts/audit-sp-invariant.sh

sp-verify-all: sp-analyze sp-audit
	@echo "🧪 Running SP Flutter tests"
	@fvm flutter test \
		test/features/sp \
		test/features/settings/presentation/bloc/settings_cubit_dev_mode_test.dart \
		test/features/settings/ui/bitcoin_settings_screen_test.dart \
		test/features/wallet/presentation/bloc/wallet_bloc_sp_test.dart \
		test/integration/sp_global_wiring_test.dart \
		--reporter=compact
