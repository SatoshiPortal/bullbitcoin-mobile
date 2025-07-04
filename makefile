.PHONY: all setup clean deps build-runner l10n hooks ios-pod-update

all: setup
	@echo "✨ All tasks completed!"

setup: clean deps build-runner l10n hooks ios-pod-update
	@echo "🚀 Setup complete!"

clean:
	@echo "🧹 Clean and remove pubspec.lock"
	@flutter clean && rm pubspec.lock

deps:
	@echo "🏃 Fetch dependencies"
	@flutter pub get

build-runner:
	@echo "🏗️ Build runner for json_serializable and flutter_gen"
	@dart run build_runner build --delete-conflicting-outputs

build-runner-watch:
	@echo "🏗️ Build runner for json_serializable and flutter_gen (watch mode)"
	@dart run build_runner watch --delete-conflicting-outputs
	
l10n:
	@echo "🌐 Generating translations files"
	@flutter gen-l10n

hooks:
	@CURRENT_HOOKS_PATH=$$(git config --local core.hooksPath); \
	if [ "$$CURRENT_HOOKS_PATH" = ".git_hooks/" ]; then \
		echo "✅ Git hooks already configured"; \
	else \
		echo "🔧 Setting up git pre-commit hooks"; \
		git config --local core.hooksPath .git_hooks/; \
	fi

drift-migrate:
	@echo "🔄 Strating SQLiteMigration"
	dart run drift_dev make-migrations

drift-schema:
	@echo "📚 Generating drift schema"
	dart run drift_dev schema dump lib/core/storage/sqlite_database.dart lib/core/storage/tables/bull_database

ios-pod-update:
	@echo " Fetch dependencies"
	@cd ios && pod install --repo-update && cd -

ios-sqlite-update:
	@echo "🔄 Updating SQLite"
	@cd ios && pod update sqlite3 && cd -
