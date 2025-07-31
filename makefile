.PHONY: all setup clean deps build-runner l10n hooks ios-pod-update drift-migrations docker-build docker-run test unit-test integration-test

all: setup
	@echo "✨ All tasks completed!"

setup: clean deps build-runner l10n hooks ios-pod-update
	@echo "🚀 Setup complete!"

clean:
	@echo "🧹 Clean and remove pubspec.lock and ios/Podfile.lock"
	@flutter clean && rm pubspec.lock && rm ios/Podfile.lock

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

drift-migrations:
	@echo "🔄 Create schema and sum migrations"
	dart run drift_dev make-migrations

ios-pod-update:
	@echo " Fetch dependencies"
	@cd ios && pod install --repo-update && cd -

ios-sqlite-update:
	@echo "🔄 Updating SQLite"
	@cd ios && pod update sqlite3 && cd -

feature:
	@if [ -z "$(filter-out $@,$(MAKECMDGOALS))" ]; then \
		echo "❌ Error: Please provide a feature name. Usage: make feature your_feature_name"; \
		exit 1; \
	fi
	@FEATURE_NAME=$$(echo $(filter-out $@,$(MAKECMDGOALS)) | sed 's/\([A-Z]\)/_\1/g' | sed 's/^_//' | tr '[:upper:]' '[:lower:]'); \
	echo "🎯 Creating feature: $$FEATURE_NAME"; \
	FEATURE_DIR="lib/features/$$FEATURE_NAME"; \
	if [ -d "$$FEATURE_DIR" ]; then \
		echo "❌ Error: Feature directory $$FEATURE_DIR already exists"; \
		exit 1; \
	fi; \
	echo "📁 Copying template folder..."; \
	cp -r lib/features/template "$$FEATURE_DIR"; \
	echo "🗑️ Removing _main.dart..."; \
	rm "$$FEATURE_DIR/_main.dart"; \
	echo "🔄 Replacing template references..."; \
	FEATURE_NAME_PASCAL=$$(echo $$FEATURE_NAME | sed 's/_\([a-z]\)/\U\1/g' | sed 's/^\([a-z]\)/\U\1/'); \	find "$$FEATURE_DIR" -type f -name "*.dart" -exec sed -i '' "s/Template/$$FEATURE_NAME_PASCAL/g" {} \; \
	2>/dev/null || find "$$FEATURE_DIR" -type f -name "*.dart" -exec sed -i "s/Template/$$FEATURE_NAME_PASCAL/g" {} \;; \
	echo "✅ Feature '$$FEATURE_NAME' created successfully in $$FEATURE_DIR"

%:
	@:

docker-build:
	@echo "🏗️ Building Docker image"
	@ docker build -t bull-mobile .


test: unit-test integration-test

unit-test: 
	@echo "🏃‍ running unit tests"
	@flutter test test/ --reporter=compact

integration-test:
	@echo "🧪 integration tests"
	@flutter test integration_test/ --reporter=compact