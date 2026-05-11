.PHONY: all setup clean deps build-runner translations hooks ios-pod-update drift-migrations devcontainer container-tools container-app apk verify test unit-test integration-test fvm-check

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
	@echo "🧹 Clean and remove pubspec.lock and ios/Podfile.lock"
	@fvm flutter clean && rm -f pubspec.lock && rm -f ios/Podfile.lock

deps:
	@echo "🏃 Fetch dependencies"
	@fvm flutter pub get

build-runner:
	@echo "🏗️ Build runner for json_serializable and flutter_gen"
	@fvm dart run build_runner build --delete-conflicting-outputs --force-jit

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

# Allow "make apk release" or "make apk debug" syntax
ifneq (,$(filter release,$(MAKECMDGOALS)))
  MODE := release
endif
ifneq (,$(filter debug,$(MAKECMDGOALS)))
  MODE := debug
endif
release debug:
	@:

# Flutter writes APK and AAB to different paths
ifeq ($(FORMAT),aab)
  CONTAINER_OUTPUT := /app/build/app/outputs/bundle/$(MODE)/app-$(MODE).aab
  HOST_OUTPUT := ./app-$(MODE).aab
  FLUTTER_BUILD := fvm flutter build appbundle --$(MODE)
else
  CONTAINER_OUTPUT := /app/build/app/outputs/flutter-apk/app-$(MODE).apk
  HOST_OUTPUT := ./app-$(MODE).apk
  FLUTTER_BUILD := fvm flutter build apk --$(MODE)
endif

apk: container-app
	@echo "🔨 Building $(FORMAT) ($(MODE)) via $(CONTAINER)"
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
			export SOURCE_DATE_EPOCH CARGO_ENCODED_RUSTFLAGS CARGO_PROFILE_RELEASE_CODEGEN_UNITS && \
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

integration-test:
	@echo "🧪 integration tests"
	@fvm flutter test integration_test/ --reporter=compact
