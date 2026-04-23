import 'dart:io';

import 'package:bb_mobile/core/storage/drift_schema_version.dart';
import 'package:bb_mobile/core/utils/prefs_keys.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reports migration errors and migration transitions to Sentry. Migration
/// events bypass the user's general error-reporting consent so that we can
/// diagnose upgrade problems even for users who opted out of telemetry —
/// `beforeSend` in `main.dart` lets events through when the scope tag
/// `category=migration` is set.
///
/// Durability: the Sentry Android/iOS native SDKs persist envelopes to an
/// on-disk outbox as part of `captureException` / `captureMessage`. If the
/// app crashes between `await` returning and the network send completing,
/// the envelope is retransmitted on the next launch. We do not attempt an
/// explicit flush (no public API for it in sentry_flutter 9) — callers can
/// `rethrow` immediately after awaiting these methods.
class MigrationReporter {
  MigrationReporter._();

  /// In-memory enrichment set once by `Bull.init` after the app-version
  /// transition is known. Migration events fired before it is populated
  /// (e.g. during `initLocator`) will simply omit the from/to tags — the
  /// storage-state tags still identify the affected install.
  static String? currentFromAppVersion;
  static String? currentToAppVersion;

  static Future<void> reportError({
    String? message,
    required Object exception,
    required StackTrace stackTrace,
    Map<String, String>? storageState,
    String type = 'error',
  }) async {
    if (!Sentry.isEnabled) return;
    final state = storageState ?? await currentStorageState();
    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      hint: Hint.withMap({
        'message': message ?? exception.runtimeType.toString(),
      }),
      withScope: (scope) => _applyTags(scope, type, state),
    );
  }

  static Future<void> reportTransition({
    required String transitionType,
    String? fromAppVersion,
    String? toAppVersion,
    Map<String, String>? storageState,
  }) async {
    if (!Sentry.isEnabled) return;
    final state = storageState ?? await currentStorageState();
    await Sentry.captureMessage(
      'migration_$transitionType',
      level: SentryLevel.info,
      withScope: (scope) => _applyTags(
        scope,
        transitionType,
        state,
        fromOverride: fromAppVersion,
        toOverride: toAppVersion,
      ),
    );
  }

  static void _applyTags(
    Scope scope,
    String type,
    Map<String, String> storageState, {
    String? fromOverride,
    String? toOverride,
  }) {
    scope.setTag('category', 'migration');
    scope.setTag('type', type);
    final from = fromOverride ?? currentFromAppVersion;
    final to = toOverride ?? currentToAppVersion;
    if (from != null) scope.setTag('from_app_version', from);
    if (to != null) scope.setTag('to_app_version', to);
    storageState.forEach(scope.setTag);
  }

  /// Snapshots observable storage state using only prefs + filesystem — safe
  /// to call before the locator is ready.
  static Future<Map<String, String>> currentStorageState() async {
    final prefs = await SharedPreferences.getInstance();
    final fssLibrary = prefs.getString(PrefsKeys.fssLibrary) ?? 'unknown';
    final docsDir = await getApplicationDocumentsDirectory();
    // OldHiveDatasource opens a box named 'store' — Hive stores it on disk as
    // 'store.hive' alongside a 'store.lock' file under the app docs directory.
    final hivePresent = await File(p.join(docsDir.path, 'store.hive')).exists();
    return {
      'fss_library': fssLibrary,
      'drift_schema_version': kDriftSchemaVersion.toString(),
      'hive_present': hivePresent.toString(),
    };
  }
}
