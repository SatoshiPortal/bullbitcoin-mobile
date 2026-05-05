import 'dart:async';
import 'dart:math';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MigrationType { install, upgrade }

/// Breadcrumb categories whose `message`/`data` are considered safe to
/// keep on the wire — neither carries wallet payloads nor user identity.
/// Anything outside this set has its message + data stripped in
/// `beforeSend`, so cubit-state breadcrumbs (which can hold addresses,
/// balances, descriptors, txids) never leave the device.
const _safeBreadcrumbCategories = <String>{'navigation', 'app.lifecycle'};

class Report {
  static const _consentKey = 'error_reporting_consent';
  static const _lastVersionKey = 'last_seen_app_version';
  static const _installUuidKey = 'install_uuid';

  static String? fromVersion;
  static String? toVersion;

  /// Random opaque per-install identifier. Generated once on first
  /// launch and persisted in [SharedPreferences] under [_installUuidKey].
  /// Forwarded to Sentry as `event.user.id` purely to
  /// distinguish "1 install crashed 1000 times" from "1000 installs
  /// crashed once" — there is no auth in BULL, no link to identity, and
  /// the value resets on uninstall.
  static String? installUuid;

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

    // The pre-init upgrade-path wizard answers consent for this very
    // boot — pass it through so migrations + Drift schema work + Sentry
    // init see the user's freshest choice. Falls back to the prefs
    // mirror for fresh installs (where the pre-init wizard is skipped)
    // and for existing users between launches.
    consent = wizardConsent ?? prefs.getBool(_consentKey) ?? false;

    var uuid = prefs.getString(_installUuidKey);
    if (uuid == null) {
      uuid = _generateInstallUuid();
      await prefs.setString(_installUuidKey, uuid);
    }
    installUuid = uuid;

    await _initSentry();
  }

  /// 128-bit hex string generated via `Random.secure()`. Not RFC 4122
  /// formatted — Sentry's `user.id` accepts any opaque string, and we
  /// avoid pulling in a `uuid` package dependency for a 4-line helper.
  static String _generateInstallUuid() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<void> _initSentry() async {
    if (!kReleaseMode) return;

    await SentryFlutter.init((options) {
      options.dsn = ApiServiceConstants.sentryDsn;
      options.compressPayload = true;
      options.debug = false;

      // ── PII and identification
      options.sendDefaultPii = false;
      options.attachThreads = false;
      options.reportPackages = false;
      options.considerInAppFramesByDefault = true;

      // ── Screen content capture
      options.attachScreenshot = false;
      options.attachViewHierarchy = false;
      options.replay.sessionSampleRate = 0.0;
      options.replay.onErrorSampleRate = 0.0;

      // ── Logs and prints ───────────────────────────────────────────
      options.enableLogs = false;
      options.enablePrintBreadcrumbs = false;

      // ── User-interaction tracking ─────────────────────────────────
      options.enableUserInteractionBreadcrumbs = false;
      options.enableUserInteractionTracing = false;
      options.enableWindowMetricBreadcrumbs = false;
      options.enableAppLifecycleBreadcrumbs = false;
      options.enableBrightnessChangeBreadcrumbs = false;
      options.enableTextScaleChangeBreadcrumbs = false;

      // ── Network
      options.captureFailedRequests = false;
      options.propagateTraceparent = false;

      // ── Profiling
      options.profilesSampleRate = 0.0;

      // ── Misc reporting
      options.reportSilentFlutterErrors = true;

      // ── Consent-gated
      final consent = Report.consent;
      options.sendClientReports = consent;
      options.enableAutoSessionTracking = consent;
      options.enableAutoPerformanceTracing = consent;
      options.enableAutoNativeBreadcrumbs = consent;
      options.tracesSampleRate = consent ? 0.2 : 0.0; // 0.2 instead of 1.0
      options.anrEnabled = consent;

      // ── Final scrub. Critical events bypass consent; everything is
      //    anonymized so we never leak txids, addresses, or seed-derived
      //    strings.
      options.beforeSend = (event, hint) {
        // no consent, no event
        if (!isCritical(event) && !consent) return null;

        event.exceptions?.forEach((e) => e.value = null);
        // Keep only the install UUID we set ourselves; drop anything else
        // (ip_address, username, geo, …) that could appear on `event.user`.
        final uid = event.user?.id;
        event.user = uid == null ? null : SentryUser(id: uid);
        event.request = null;

        for (final ex in event.exceptions ?? <SentryException>[]) {
          ex.stackTrace?.frames.forEach((f) => f.vars.clear());
        }

        event.threads?.forEach((t) {
          t.stacktrace?.frames.forEach((f) => f.vars.clear());
        });

        // Whitelisted categories keep their message + data so we can
        // reproduce the user journey leading up to the crash. Everything
        // else (notably `state` from the bloc integration, which mirrors
        // cubit state and can contain wallet data) is stripped down to
        // metadata only.
        event.breadcrumbs = event.breadcrumbs?.map((b) {
          final isSafe = _safeBreadcrumbCategories.contains(b.category);
          return Breadcrumb(
            category: b.category,
            level: b.level,
            timestamp: b.timestamp,
            type: b.type,
            message: isSafe ? b.message : null,
            data: isSafe ? b.data : null,
          );
        }).toList();

        return event;
      };
    });

    final uuid = installUuid;
    if (uuid != null) {
      Sentry.configureScope((scope) => scope.setUser(SentryUser(id: uuid)));
    }
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

  /// Fallback for installs that predate the `_lastVersionKey` marker
  /// (added in v6.6.0). Wired into drift's `MigrationStrategy.beforeOpen`
  /// — drift only fires the upgrade path when the on-disk schema
  /// differs from the current one, so a schema upgrade is observable
  /// even when prefs is empty. Without this, pre-v6.6.0 upgrades are
  /// misclassified as installs in Sentry. Idempotent: a populated
  /// `fromVersion` from prefs takes precedence.
  static void recordSchemaUpgrade({required int from}) {
    fromVersion ??= _versionFromSchema(from);
  }

  /// Maps a drift schema number to the first released app version that
  /// shipped with that schema. Append a new case here whenever
  /// `SqliteDatabase.schemaVersion` is bumped.
  static String _versionFromSchema(int schema) => switch (schema) {
    1 => 'v5.0.0..v5.2.0',
    2 => 'v5.3.0',
    3 => 'v5.3.1',
    4 => 'v5.4.0..v5.4.3',
    5 => 'v5.4.4',
    6 => 'v6.0.0',
    7 => 'v6.1.0..v6.2.3',
    8 => 'v6.3.0..v6.3.2',
    9 => 'v6.3.3..v6.3.8',
    10 => 'v6.4.0..v6.4.3',
    11 => 'v6.5.0..v6.5.4',
    12 => 'v6.6.0+',
    _ => 'schema-$schema',
  };

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
