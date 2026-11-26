# Bull reporting

Error reporting starts after startup consent is available in release builds. Android and iOS initialize the native Sentry SDK directly so native crash reporting can run with native logs and metrics disabled. Keep the native SDK versions in the Gradle and Swift packages aligned with `sentry_flutter` when upgrading.

Withdrawing consent stops reporting in the current session. Enabling it in Settings takes effect on the next launch.
