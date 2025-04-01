#!/bin/bash
echo "🔧 Running setup script..."

echo "🧹 Clean and remove pubspec.lock"
flutter clean && rm pubspec.lock

echo "🏃 Fetch dependencies"
flutter pub get

echo "🏗️ Build runner for json_serializable and flutter_gen"
dart run build_runner build --delete-conflicting-outputs

echo "🌐 Generates translations files"
flutter gen-l10n

echo "🙈 Set git pre-commit hooks"
git config --local core.hooksPath .git_hooks/

echo "🚀 Setup complete!"
