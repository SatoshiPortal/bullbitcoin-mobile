.PHONY: all setup clean deps deps-update bootstrap analyze build-runner translations hooks ios-pod-update ios-release drift-migrations devcontainer devcontainer-up container-tools container-app android release debug beta verify verify-rustc-pins test unit-test integration-test catalogue fvm-check

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

# Formatting gate scoped to existing git-tracked source via git ls-files: untracked generated code never trips it, deleted files are skipped, and tracked generated files are filtered by suffix and by /generated/ path segment because `dart format` does not read analysis_options.yaml `exclude:`. Keep the regex in sync with the staged-files variant in .git_hooks/pre-commit. pipefail so a git/grep failure cannot silently pass the gate (xargs -r would no-op and exit 0).
format-check:
	@echo "🎨 dart format should have nothing to change"
	@bash -c 'set -o pipefail; git ls-files "*.dart" | grep -vE "\.(g|freezed|gr|config|mocks|steps)\.dart$$|/generated/" | while IFS= read -r file; do if [ -f "$$file" ]; then printf "%s\n" "$$file"; fi; done | xargs -r fvm dart format --output=none --set-exit-if-changed'

bull-ui-check:
	@echo "🧱 bull_ui import boundary (coins/ui imports only package:bull_ui)"
	@if grep -rEl "package:flutter/(material|cupertino|widgets)\.dart" lib/features/coins/ui; then echo "lib/features/coins/ui must import only package:bull_ui/bull_ui.dart, not Flutter UI directly"; exit 1; fi

checks: analyze bull-ui-check fix-check format-check unit-test

build-runner:
	@echo "🏗️ Build runner for json_serializable and flutter_gen"
	@fvm dart run build_runner build --force-jit --delete-conflicting-outputs
	@(cd packages/bull_payjoin && fvm dart run build_runner build --force-jit)

build-runner-watch:
	@echo "🏗️ Build runner for json_serializable and flutter_gen (watch mode)"
	@bash -c 'trap "kill \$$(jobs -p) 2>/dev/null || true" INT TERM EXIT; fvm dart run build_runner watch --delete-conflicting-outputs --force-jit & (cd packages/bull_payjoin && fvm dart run build_runner watch --force-jit) & wait'

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
	cd packages/bull_payjoin && fvm dart run drift_dev make-migrations

ios-pod-update:
	@if [ "$$(uname)" != "Darwin" ]; then echo "Skipping pod update (not macOS)"; exit 0; fi
	@echo "Fetching iOS dependencies"
	@fvm flutter precache --ios
	@cd ios && pod install --repo-update && cd -

ios-sqlite-update:
	@if [ "$$(uname)" != "Darwin" ]; then echo "Skipping pod update (not macOS)"; exit 0; fi
	@echo "Updating SQLite"
	@cd ios && pod update sqlite3 && cd -

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
# beta banner (lib/main.dart).
	@backup="$$(mktemp)"; cp pubspec.yaml "$$backup" \
	  && trap 'cp "$$backup" pubspec.yaml; rm -f "$$backup"' EXIT INT TERM \
	  && grep -v '^[[:space:]]*default-flavor:' "$$backup" > pubspec.yaml \
	  && fvm flutter build ipa --release --build-number "$(BUILD_NUMBER)" $(if $(EXPORT_OPTIONS_PLIST),--export-options-plist "$(EXPORT_OPTIONS_PLIST)") $(FLUTTER_EXTRA_ARGS)

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
		--build-arg BDK_RUST_VERSION=$(BDK_RUST_VERSION) \
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
	@if [ "$(FORMAT)" = "apk" ]; then $(MAKE) --no-print-directory verify-rustc-pins APK=$(HOST_OUTPUT); fi

# Guards against the rustup shim in Containerfile.tools regressing: without it,
# cargokit's `rustup run stable` silently uses whatever upstream Rust is current
# on build day instead of the pinned version, breaking reproducibility invisibly
# (this is exactly how it broke before — two builds on the same day matched by
# coincidence, not by pinning). Compares the rustc version string every compiler
# embeds in its output against the pinned toolchains running live inside bull-app.
#
# Fails CLOSED: an empty/failed toolchain lookup, a tracked lib present with no
# embedded version, a version mismatch, or zero tracked Rust libs found all
# ABORT — a green result must mean the pins were actually checked, never that a
# check was skipped. Keep TRACKED_RUST_LIBS in sync with the case below; a lib
# from that list that is absent from the APK is reported loudly (a build should
# ship all of them, but we only warn rather than hard-fail here because the exact
# shipped set is confirmed by a real build, not by this static guard). Any
# shipped Rust .so NOT in the list (e.g. a newly added plugin, or ark/boltz if
# they ever ship as standalone OpenSSL-linking libs rather than statically
# linked into librust_lib_bull_sdk.so) prints an ℹ️ line naming it and its
# embedded rustc, so a real build surfaces the gap — add it to the list + case
# to promote it from info to a verified pin.
#
# Single source of truth for bdk_dart's pinned Rust channel: passed as a
# --build-arg to Containerfile.tools (overriding its default) AND used below to
# read the live pin out of bull-app. Keep in sync with the `channel` in
# bdk-dart's native/rust-toolchain.toml (bdk_dart is transitive via bull_sdk).
BDK_RUST_VERSION ?= 1.85.1
TRACKED_RUST_LIBS := libbdk_dart_ffi.so libtor.so libpayjoin_flutter.so librust_lib_bull_sdk.so
verify-rustc-pins:
	@command -v strings >/dev/null 2>&1 || { echo "❌ 'strings' (binutils) not found — cannot verify rustc pins. Install binutils; failing closed rather than skipping the check (a skipped check must never read as green)."; exit 1; }
	@tmpdir=$$(mktemp -d); \
	trap 'rm -rf "$$tmpdir"' EXIT; \
	unzip -q -o "$(APK)" -d "$$tmpdir" 'lib/*/*.so' 2>/dev/null || true; \
	abi_dirs=$$(find "$$tmpdir/lib" -mindepth 1 -maxdepth 1 -type d 2>/dev/null); \
	if [ -z "$$abi_dirs" ]; then echo "❌ no native libraries extracted from $(APK) (unreadable APK, or no lib/*/*.so) — cannot verify rustc pins"; exit 1; fi; \
	echo "🔎 Verifying Rust libraries embed the pinned rustc versions..."; \
	cargokit_rustc=$$($(CONTAINER) run --rm bull-app rustup run stable rustc --version | awk '{print $$2}'); \
	bdk_rustc=$$($(CONTAINER) run --rm bull-app rustup run $(BDK_RUST_VERSION) rustc --version | awk '{print $$2}'); \
	if [ -z "$$cargokit_rustc" ] || [ -z "$$bdk_rustc" ]; then \
		echo "❌ could not read pinned toolchain versions from bull-app (cargokit='$$cargokit_rustc' bdk='$$bdk_rustc') — cannot verify rustc pins"; \
		exit 1; \
	fi; \
	fail=0; seen=" "; \
	for abi_dir in $$abi_dirs; do \
		abi=$$(basename "$$abi_dir"); \
		echo "  · ABI $$abi"; \
		for so in "$$abi_dir"/*.so; do \
			[ -e "$$so" ] || { echo "❌ no .so files under $$abi_dir — cannot verify rustc pins"; exit 1; }; \
			name=$$(basename "$$so"); \
			case "$$name" in \
				libbdk_dart_ffi.so) expected="$$bdk_rustc" ;; \
				libtor.so|libpayjoin_flutter.so|librust_lib_bull_sdk.so) expected="$$cargokit_rustc" ;; \
				*) expected="" ;; \
			esac; \
			embedded=$$(strings "$$so" 2>/dev/null | grep -m1 -o 'rustc version [0-9][0-9A-Za-z.+-]*' | awk '{print $$3}'); \
			if [ -z "$$expected" ]; then \
				[ -n "$$embedded" ] && echo "      ℹ️  $$name: rustc $$embedded (no pin tracked, add it to TRACKED_RUST_LIBS + the case above if this is a new Rust plugin)"; \
				continue; \
			fi; \
			seen="$$seen$$abi/$$name "; \
			if [ -z "$$embedded" ]; then \
				echo "      ❌ $$name: tracked Rust lib but no embedded 'rustc version' string found (stripped, or the grep pattern needs updating)"; \
				fail=1; continue; \
			fi; \
			if [ "$$embedded" != "$$expected" ]; then \
				echo "      ❌ $$name: embedded rustc $$embedded, expected pinned $$expected"; \
				fail=1; \
			else \
				echo "      ✅ $$name: rustc $$embedded (matches pin)"; \
			fi; \
		done; \
	done; \
	checked=0; \
	for want in $(TRACKED_RUST_LIBS); do \
		case "$$seen" in *"/$$want "*) checked=$$((checked+1)) ;; *) echo "  ⚠️  expected Rust lib $$want not found in any ABI of $(APK) — its pin was NOT verified" ;; esac; \
	done; \
	if [ "$$checked" = "0" ]; then \
		echo "❌ none of the tracked Rust libs ($(TRACKED_RUST_LIBS)) were found — the rustc-pin check verified nothing; treating as failure"; \
		exit 1; \
	fi; \
	if [ "$$fail" = "1" ]; then \
		echo "❌ A Rust library was not built with its pinned toolchain — reproducibility is broken. Check the rustup shim in Containerfile.tools."; \
		exit 1; \
	fi; \
	echo "✅ Tracked Rust libraries embed their pinned rustc versions (all ABIs)."

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
	@set -e; for p in packages/*/; do \
		if [ -d "$${p}test" ]; then \
			echo "🏃‍ running $${p}test"; \
			if grep -qE '^  flutter:$$' "$${p}pubspec.yaml"; then \
				( cd "$$p" && fvm flutter test --reporter=compact ); \
			else \
				( cd "$$p" && fvm dart test --reporter=compact ); \
			fi; \
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
