import 'package:bull_reporting/bull_reporting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Dart options drop logs, metrics, and crash reports without consent',
    () async {
      final options = SentryFlutterOptions();
      const dsn = 'https://public@example.invalid/1';
      Report.configureSentryOptions(options, dsn: dsn);
      final log = SentryLog(
        timestamp: DateTime.utc(2026),
        level: SentryLogLevel.info,
        body: 'test log',
        traceId: SentryId.newId(),
        attributes: {},
      );
      final metric = SentryCounterMetric(
        name: 'test_count',
        value: 1,
        timestamp: DateTime.utc(2026),
        traceId: SentryId.newId(),
      );
      final event = SentryEvent(throwable: Exception('test exception'));

      expect(options.autoInitializeNativeSdk, isTrue);
      expect(options.captureNativeFailedRequests, isFalse);
      expect(options.beforeSendLog, isNotNull);
      expect(options.beforeSendMetric, isNotNull);
      expect(await options.beforeSendLog?.call(log, Hint()), isNull);
      expect(await options.beforeSendMetric?.call(metric, Hint()), isNull);

      Report.consent = false;
      expect(await options.beforeSend?.call(event, Hint()), isNull);
      Report.consent = true;
      expect(await options.beforeSend?.call(event, Hint()), same(event));
      Report.consent = false;
    },
  );

  test(
    'refresh updates the live gate without accessing the boot mirror',
    () async {
      Report.consent = true;

      await Report.refreshConsent(() async => false);

      expect(Report.consent, isFalse);
    },
  );

  // No SharedPreferences mock is installed, so the boot-mirror write throws
  // (no platform channel) — the failure SettingsRepository swallows.
  test('an opt-out turns the live gate off even when the mirror write '
      'fails', () async {
    Report.consent = true;

    await expectLater(Report.updateConsent(false), throwsA(anything));

    // beforeSend reads this flag, so it must already be off: otherwise the
    // switch reads "off" while events keep going out for the session.
    expect(Report.consent, isFalse);
  });
}
