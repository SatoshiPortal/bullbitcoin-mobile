import 'dart:async';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MigrationType { install, upgrade }

class Report {
  static const _consentKey = 'error_reporting_consent';
  static const _lastVersionKey = 'last_seen_app_version';

  static String? fromVersion;
  static String? toVersion;

  static MigrationType? get migrationType {
    if (fromVersion == null) {
      return MigrationType.install;
    } else if (fromVersion != toVersion) {
      return MigrationType.upgrade;
    } else {
      return null;
    }
  }

  /// Error-report consent at boot time, before the SQLite settings
  /// repository is available. Seeded by [init] from the prefs mirror
  /// under [_consentKey]; refreshed from SQLite once the locator is
  /// ready. Kept in sync via [updateConsent] — callers of the primary
  /// SQLite write notify here.
  static bool consent = false;

  /// Populates version context and the consent mirror so events fired
  /// during `Bull.init` (FSS fallback, Drift schema, etc.) carry
  /// from/to tags and so `SentryFlutter.init` can read consent. Safe
  /// to call before Sentry is initialized — no capture here.
  static Future<void> init({bool? wizardConsent}) async {
    final info = await PackageInfo.fromPlatform();
    final to = '${info.version}+${info.buildNumber}';

    final prefs = await SharedPreferences.getInstance();
    final from = prefs.getString(_lastVersionKey);

    fromVersion = from;
    toVersion = to;

    consent = wizardConsent ?? prefs.getBool(_consentKey) ?? false;

    await _initSentry();
  }

  static Future<void> _initSentry() async {
    await SentryFlutter.init((options) {
      options.dsn = kReleaseMode ? ApiServiceConstants.sentryDsn : '';
      options.compressPayload = true;

      // Depending on user consent to the reporting program.
      final consent = Report.consent;
      options.sendClientReports = consent;
      options.enableAutoSessionTracking = consent;
      options.enableAutoPerformanceTracing = consent;
      options.tracesSampleRate = consent ? 1.0 : 0;
      options.enableAutoNativeBreadcrumbs = consent;

      // Set to false by default
      options.captureFailedRequests = false;
      options.enableUserInteractionBreadcrumbs = false;
      options.enableUserInteractionTracing = false;

      // Consent gate: events tagged `category=critical` by [Report.critical]
      // bypass [Report.consent]; everything else is dropped when the user
      // opted out. Source of truth is [Report.isCritical]. Passing events
      // are anonymized — `e.value` is stripped — so we never leak txids,
      // addresses, or seed-derived strings.
      options.beforeSend = (event, _) {
        if (!isCritical(event) && !consent) return null;
        event.exceptions?.forEach((e) => e.value = null);
        return event;
      };
    });
  }

  /// Writes the boot-time consent mirror so the next cold start's
  /// Sentry init can read it before the SQLite locator is available.
  /// Called right after the primary SQLite write in
  /// `SettingsRepository.setErrorReportingEnabled`.
  static Future<void> updateConsent(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, enabled);
    consent = enabled;
  }

  /// Advances the persisted `_lastVersionKey` marker. Caller emits the
  /// install/upgrade milestone via `log.shout` first so a crash between
  /// the two retries the event on the next launch.
  static Future<void> commitVersion() async {
    final to = toVersion;
    if (to == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastVersionKey, to);
  }

  /// Consent-gated error capture. Dropped by `beforeSend` when the user
  /// has opted out of the error-report program. Tagged `category=error`.
  /// Routed from `log.severe`.
  static Future<void> error({
    required Object exception,
    required StackTrace stackTrace,
    String? message,
  }) async {
    if (!Sentry.isEnabled) return;
    Future.microtask(
      () => Sentry.captureException(
        exception,
        stackTrace: stackTrace,
        withScope: (s) {
          if (message != null) _applyContexts(s, message);
          _applyTags(s, critical: false);
        },
      ),
    );
  }

  /// Always-reported event. Bypasses user consent — `beforeSend` lets
  /// it through via [isCritical]. Tagged `category=critical`. When
  /// [exception] and [stackTrace] are both set, captured as an
  /// exception; otherwise captured as an info-level message. Routed
  /// from `log.shout`. Use for critical errors AND for milestones we
  /// need regardless of consent (install/upgrade, FSS fallback, etc.).
  static Future<void> critical({
    required String message,
    Object? exception,
    StackTrace? stackTrace,
  }) async {
    if (!Sentry.isEnabled) return;
    Future.microtask(() async {
      if (exception != null && stackTrace != null) {
        await Sentry.captureException(
          exception,
          stackTrace: stackTrace,
          withScope: (s) {
            _applyContexts(s, message);
            _applyTags(s, critical: true);
          },
        );
      } else {
        await Sentry.captureMessage(
          message,
          level: SentryLevel.info,
          withScope: (s) => _applyTags(s, critical: true),
        );
      }
    });
  }

  /// Single predicate `beforeSend` uses to decide consent bypass.
  /// Returns true for events emitted via [critical]; false for events
  /// emitted via [error]. The `category` tag is the source of truth.
  static bool isCritical(SentryEvent event) =>
      event.tags?['category'] == 'critical';

  static void _applyTags(Scope scope, {required bool critical}) {
    scope.setTag('category', critical ? 'critical' : 'error');
    if (migrationType != null) {
      scope.setTag('migration_type', migrationType!.name);
      if (fromVersion != null) scope.setTag('from_version', fromVersion!);
      if (toVersion != null) scope.setTag('to_version', toVersion!);
    }
  }

  static void _applyContexts(Scope scope, String message) {
    scope.setContexts('bull', {'dev_message': message});
  }
}
