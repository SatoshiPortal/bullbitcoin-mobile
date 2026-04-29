.PHONY: all setup clean deps build-runner translations hooks ios-pod-update drift-migrations devcontainer docker-build apk verify test unit-test integration-test fvm-check

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
	@fvm flutter pub get

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

docker-build:
	@echo "🏗️ Building Docker image"
	@docker build -t bull-mobile \
		--build-arg FLUTTER_VERSION=$$(awk 'BEGIN{RS="";} { gsub(/\r/,""); s=$$0; sub(/.*"flutter"[[:space:]]*:[[:space:]]*"/,"",s); sub(/".*$$/,"",s); print s; exit }' .fvmrc) \
		--build-arg JVM_TARGET=$$(grep 'android.jvmTarget' android/gradle.properties | cut -d= -f2) \
		--build-arg ANDROID_API_LEVEL=$$(grep 'android.compileSdk' android/gradle.properties | cut -d= -f2) \
		--build-arg ANDROID_BUILD_TOOLS=$$(grep 'android.buildToolsVersion' android/gradle.properties | cut -d= -f2) \
		--build-arg ANDROID_NDK=$$(grep 'android.ndkVersion' android/gradle.properties | cut -d= -f2) \
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

apk: docker-build
	@echo "🔨 Building $(FORMAT) ($(MODE)) via Docker"
	@docker build -f Dockerfile.apk \
		--build-arg MODE=$(MODE) \
		--build-arg FORMAT=$(FORMAT) \
		--build-arg GRADLE_HEAP=$(or $(GRADLE_HEAP),4g) \
		--ulimit nofile=65536:65536 \
		-t bull-mobile-apk .
	@docker rm -f bull-apk-extract > /dev/null 2>&1 || true
	@docker create --name bull-apk-extract bull-mobile-apk > /dev/null
	@docker cp bull-apk-extract:/app/build/app/outputs/flutter-apk/app-$(MODE).apk ./app-$(MODE).apk
	@docker rm bull-apk-extract > /dev/null
	@echo "✅ APK extracted: ./app-$(MODE).apk"
	@sha256sum ./app-$(MODE).apk

verify:
	@echo "🔍 Verifying reproducible build"
	@./reproducibility/verify_build.sh $(if $(VERSION),--version $(VERSION)) $(if $(APK),--apk $(APK))

devcontainer:
	@echo "🏗️ Building Dev Container"
	@devcontainer up --workspace-folder . --config ./.devcontainer/devcontainer.json

test: unit-test integration-test

unit-test:
	@echo "🏃‍ running unit tests"
	@fvm flutter test test/ --reporter=compact

integration-test:
	@echo "🧪 integration tests"
	@fvm flutter test integration_test/ --reporter=compact
