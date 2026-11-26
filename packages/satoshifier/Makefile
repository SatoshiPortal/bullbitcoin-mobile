.PHONY: setup test deps clean unit-test integration-test clean build build-watch pod-update


setup: clean deps build
	@echo "🚀 Setup complete!"

# Keeps pubspec.lock. It is committed, and its sha256 hashes are the only
# integrity anchor for dependencies that parse untrusted scanner input —
# bip21_uri, bip32_keys, bs58 and friends are caret-ranged, single-maintainer
# packages with no signed releases. Deleting it here made every `make setup`
# re-resolve them, so a poisoned patch release would have been picked up
# silently. Re-resolve deliberately with `flutter pub upgrade` instead.
clean:
	@echo "🧹 Clean"
	@flutter clean

deps:
	@echo "🐕 Fetching dependencies"
	@flutter pub get

test: unit-test integration-test

unit-test: 
	@echo "🏃‍ running unit tests"
	@flutter test test/ --reporter=compact

integration-test:
	@echo "🧪 integration tests"
	@cd example && flutter test integration_test/ --reporter=compact

build:
	@echo "🏗️ Building"
	@dart run build_runner build --delete-conflicting-outputs

build-watch:
	@echo "🚧 Building (watch)"
	@dart run build_runner watch --delete-conflicting-outputs

pod-update:
	@echo " Refresh pods"
	@cd example/ios && pod install --repo-update
