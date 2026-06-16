.PHONY: all setup clean deps deps-update bootstrap analyze build-runner translations hooks ios-pod-update drift-migrations devcontainer container-tools container-app android release debug beta verify test unit-test integration-test catalogue fvm-check

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

build-runner:
	@echo "🏗️ Build runner for json_serializable and flutter_gen"
	@fvm dart run build_runner build --force-jit

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

container-tools:
	@echo "🔧 Building tools image"
	@$(CONTAINER) build -f Containerfile.tools -t bull-tools \
		--build-arg FLUTTER_VERSION=$$(awk 'BEGIN{RS="";} { gsub(/\r/,""); s=$$0; sub(/.*"flutter"[[:space:]]*:[[:space:]]*"/,"",s); sub(/".*$$/,"",s); print s; exit }' .fvmrc) \
		--build-arg JVM_TARGET=$$(grep 'android.jvmTarget' android/gradle.properties | cut -d= -f2) \
		--build-arg ANDROID_API_LEVEL=$$(grep 'android.compileSdk' android/gradle.properties | cut -d= -f2) \
		--build-arg ANDROID_BUILD_TOOLS=$$(grep 'android.buildToolsVersion' android/gradle.properties | cut -d= -f2) \
		--build-arg ANDROID_NDK=$$(grep 'android.ndkVersion' android/gradle.properties | cut -d= -f2) \
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

devcontainer: container-tools
	@echo "🏗️ Building Dev Container"
	@devcontainer up --workspace-folder . --config ./.devcontainer/devcontainer.json

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
# tool/gen_all_test.dart regenerates it from disk below, so adding a test file
# needs no manual wiring.
integration-test:
	@echo "🧪 integration tests"
	@fvm dart run tool/gen_all_test.dart
	@fvm flutter test integration_test/all_test.dart --reporter=expanded

# Build & render the bull_ui design-system catalogue (Widgetbook) locally in the
# browser. Dev-only tooling — never shipped in the app. Regenerates the
# @UseCase directories, then runs the catalogue app on Chrome (hot-reload).
catalogue:
	@echo "📚 Building & rendering the bull_ui catalogue in the browser"
	@cd packages/bull_ui_catalogue && \
		fvm dart run build_runner build --delete-conflicting-outputs && \
		fvm flutter run -d chrome
