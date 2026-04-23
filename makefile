.PHONY: all setup clean deps build-runner translations hooks ios-pod-update drift-migrations devcontainer docker-build build verify test unit-test integration-test fvm-check lock-android-deps

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
	@fvm dart run build_runner build --delete-conflicting-outputs

build-runner-watch:
	@echo "🏗️ Build runner for json_serializable and flutter_gen (watch mode)"
	@fvm dart run build_runner watch --delete-conflicting-outputs

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

# Allow "make build release" or "make build debug" syntax
ifneq (,$(filter release,$(MAKECMDGOALS)))
  MODE := release
endif
ifneq (,$(filter debug,$(MAKECMDGOALS)))
  MODE := debug
endif
release debug:
	@:

build: docker-build
	@if [ -n "$$KEYSTORE" ]; then \
		if [ -z "$$KEYSTORE_PASS" ] || [ -z "$$KEY_ALIAS" ] || [ -z "$$KEY_PASS" ]; then \
			echo "❌ Signed builds require all of: KEYSTORE, KEYSTORE_PASS, KEY_ALIAS, KEY_PASS"; exit 1; \
		fi; \
		if [ ! -f "$$KEYSTORE" ]; then echo "❌ Keystore file not found: $$KEYSTORE"; exit 1; fi; \
	fi
	@echo "🔨 Building AAB + universal APK ($(MODE))"
	@EXTRA_ARGS=""; \
	if [ -n "$$KEYSTORE" ]; then \
		KEYSTORE_ABS=$$(realpath "$$KEYSTORE"); \
		case "$$KEYSTORE_ABS" in *[[:space:]]*) echo "❌ KEYSTORE path must not contain spaces"; exit 1 ;; esac; \
		EXTRA_ARGS="-v $$(dirname $$KEYSTORE_ABS):/keys:ro \
			-e KEYSTORE_FILE=$$(basename $$KEYSTORE_ABS) \
			-e KEYSTORE_PASS -e KEY_ALIAS -e KEY_PASS"; \
	fi; \
	USERNS_ARGS=""; \
	if docker --version 2>/dev/null | grep -qi podman \
	   || readlink -f "$$(command -v docker 2>/dev/null)" 2>/dev/null | grep -qi podman; then \
		USERNS_ARGS="--userns=keep-id:uid=1000,gid=1000"; \
	fi; \
	docker run --rm \
		$$USERNS_ARGS \
		-v "$(CURDIR):/app" \
		-e MODE=$(MODE) \
		-e GRADLE_HEAP=$(or $(GRADLE_HEAP),4g) \
		$$EXTRA_ARGS \
		bull-mobile \
		bash /app/scripts/build.sh

verify:
	@echo "🔍 Verifying reproducible build"
	@./scripts/verify_build.sh $(if $(VERSION),--version $(VERSION)) $(if $(APK),--apk $(APK))

lock-android-deps: fvm-check
	@echo "🔒 Generating Android Gradle lockfile"
	@fvm flutter pub get
	@./android/gradlew -p android :app:dependencies --write-locks

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
