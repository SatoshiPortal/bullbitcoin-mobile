import 'dart:async';
import 'dart:io';

import 'package:bull_reporting/bull_reporting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bull_reporting/src/metrics/statistics_consent.dart';

final class FakeConsentStore implements StatisticsConsentStore {
  bool enabled = false;
  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;
  Completer<void>? writeGate;

  @override
  Future<bool> read() async {
    if (failRead) throw const FileSystemException('read');
    return enabled;
  }

  @override
  Future<void> activate() async {
    await writeGate?.future;
    if (failWrite) throw const FileSystemException('write');
    enabled = true;
  }

  @override
  Future<void> revoke() async {
    if (failDelete) throw const FileSystemException('delete');
    enabled = false;
  }
}

void main() {
  test('missing and unreadable consent are off', () async {
    final store = FakeConsentStore();
    expect(await StatisticsConsent(store).initialize(), isFalse);
    store.failRead = true;
    expect(await StatisticsConsent(store).initialize(), isFalse);
  });

  test('activation and successful revocation survive restart', () async {
    final store = FakeConsentStore();
    final first = StatisticsConsent(store);
    expect(await first.initialize(), isFalse);
    expect(await first.setEnabled(true), isTrue);
    expect(await StatisticsConsent(store).initialize(), isTrue);
    expect(await first.setEnabled(false), isTrue);
    expect(await StatisticsConsent(store).initialize(), isFalse);
  });

  test(
    'statistics consent does not change the error-reporting choice',
    () async {
      final store = FakeConsentStore();
      final consent = StatisticsConsent(store);
      for (final reporting in [false, true]) {
        Report.consent = reporting;
        expect(await consent.setEnabled(true), isTrue);
        expect(Report.consent, reporting);
        expect(await consent.setEnabled(false), isTrue);
        expect(Report.consent, reporting);
      }
      Report.consent = false;
    },
  );

  test('failed revocation closes the live gate and reports failure', () async {
    final store = FakeConsentStore()..enabled = true;
    final consent = StatisticsConsent(store);
    await consent.initialize();
    store.failDelete = true;
    final result = consent.setEnabled(false);
    expect(consent.enabled, isFalse);
    expect(await result, isFalse);
    // Total storage failure cannot erase a previously durable opt-in.
    expect(await StatisticsConsent(store).initialize(), isTrue);
    store.failDelete = false;
    expect(await consent.setEnabled(false), isTrue);
    expect(await StatisticsConsent(store).initialize(), isFalse);
  });

  test('withdrawal supersedes an activation already in flight', () async {
    final gate = Completer<void>();
    final store = FakeConsentStore()..writeGate = gate;
    final consent = StatisticsConsent(store);
    final activation = consent.setEnabled(true);
    final withdrawal = consent.setEnabled(false);
    gate.complete();
    expect(await activation, isTrue);
    expect(await withdrawal, isTrue);
    expect(consent.enabled, isFalse);
    expect(await StatisticsConsent(store).initialize(), isFalse);
  });

  test('failed activation never opens the gate', () async {
    final consent = StatisticsConsent(FakeConsentStore()..failWrite = true);
    expect(await consent.setEnabled(true), isFalse);
    expect(consent.enabled, isFalse);
  });

  test('file store accepts only a complete marker', () async {
    final directory = await Directory.systemTemp.createTemp('stats-consent-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/enabled');
    final store = FileStatisticsConsentStore(() async => file);
    expect(await store.read(), isFalse);
    await file.writeAsString('invalid');
    expect(await store.read(), isFalse);
    await store.activate();
    expect(await store.read(), isTrue);
    await store.revoke();
    expect(await store.read(), isFalse);
  });

  test('file store does not report an undeletable marker as revoked', () async {
    final directory = await Directory.systemTemp.createTemp('stats-consent-');
    addTearDown(() => directory.delete(recursive: true));
    final markerDirectory = Directory('${directory.path}/enabled');
    await markerDirectory.create();
    final store = FileStatisticsConsentStore(
      () async => File(markerDirectory.path),
    );
    await expectLater(store.revoke(), throwsA(isA<FileSystemException>()));
  });
}
