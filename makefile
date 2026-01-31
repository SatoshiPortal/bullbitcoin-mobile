.PHONY: all setup clean deps build-runner translations hooks ios-pod-update drift-migrations docker-build docker-run test unit-test integration-test fvm-check build

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

setup: fvm-check clean deps build-runner translations hooks ios-pod-update
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
	@echo " Fetching dependencies"
	@fvm flutter precache --ios
	@cd ios && pod install --repo-update && cd -

ios-sqlite-update:
	@echo "🔄 Updating SQLite"
	@cd ios && pod update sqlite3 && cd -

docker-build:
	@echo "🏗️ Building Docker image"
	@ docker build -t bull-mobile .

MODE ?= debug
FORMAT ?= apk

build:
	@echo "🔨 Building $(FORMAT) ($(MODE))"
	@RUSTFLAGS="--remap-path-prefix=$$HOME/.cargo=/cargo --remap-path-prefix=$$(pwd)=/build" \
		fvm flutter build $(if $(filter aab,$(FORMAT)),appbundle,apk) --$(MODE)

test: unit-test integration-test

unit-test: 
	@echo "🏃‍ running unit tests"
	@fvm flutter test test/ --reporter=compact

integration-test:
	@echo "🧪 integration tests"
	@fvm flutter test integration_test/ --reporter=compact
