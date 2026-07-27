import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/data/shared_preferences_backup_health_reminder_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_health_reminder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fingerprint = 'f00dbabe';
  late SharedPreferencesBackupHealthReminderRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = SharedPreferencesBackupHealthReminderRepository();
  });

  Future<BackupHealthReminderRecord> fetchRecord() async =>
      switch (await repository.fetch(fingerprint)) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError(
          failure.logMessage ?? 'Reminder fetch failed',
        ),
      };

  test('returns an empty versioned record when none has been saved', () async {
    final record = await fetchRecord();

    expect(record.masterFingerprint, fingerprint);
    expect(record.lastAcknowledgedAt, isNull);
    expect(record.crossedTenMillionSats, isFalse);
  });

  test(
    'round-trips the acknowledgement and the milestone flag in UTC',
    () async {
      final acknowledgedAt = DateTime.parse('2026-07-27T08:00:00-04:00');

      final saved = await repository.save(
        BackupHealthReminderRecord(
          masterFingerprint: fingerprint,
          lastAcknowledgedAt: acknowledgedAt,
          crossedTenMillionSats: true,
        ),
      );
      expect(saved, isA<Ok>());

      final record = await fetchRecord();
      expect(record.lastAcknowledgedAt, acknowledgedAt.toUtc());
      expect(record.crossedTenMillionSats, isTrue);
    },
  );

  test('keys from an earlier record shape are ignored, not rejected', () async {
    SharedPreferences.setMockInitialValues({
      'backup_health_reminder_v1_$fingerprint':
          '{"version":1,"lastAcknowledgedAt":1784000000000,'
          '"highestHandledBalanceTier":"oneMillion",'
          '"pendingActionStartedAt":1784000000001,'
          '"pendingActionBalanceTier":"tenMillion"}',
    });

    final record = await fetchRecord();

    expect(
      record.lastAcknowledgedAt,
      DateTime.fromMillisecondsSinceEpoch(1784000000000, isUtc: true),
    );
    expect(record.crossedTenMillionSats, isFalse);
  });

  test('corrupt state fails safely to an empty record', () async {
    SharedPreferences.setMockInitialValues({
      'backup_health_reminder_v1_$fingerprint': '{not-json',
    });

    final record = await fetchRecord();

    expect(record.masterFingerprint, fingerprint);
    expect(record.lastAcknowledgedAt, isNull);
    expect(record.crossedTenMillionSats, isFalse);
  });

  test('wrongly typed state fails safely to an empty record', () async {
    SharedPreferences.setMockInitialValues({
      'backup_health_reminder_v1_$fingerprint':
          '{"version":1,"crossedTenMillionSats":"yes"}',
    });

    final record = await fetchRecord();

    expect(record.masterFingerprint, fingerprint);
    expect(record.lastAcknowledgedAt, isNull);
    expect(record.crossedTenMillionSats, isFalse);
  });

  test('non-object state fails safely to an empty record', () async {
    SharedPreferences.setMockInitialValues({
      'backup_health_reminder_v1_$fingerprint': '[]',
    });

    final record = await fetchRecord();

    expect(record.masterFingerprint, fingerprint);
    expect(record.crossedTenMillionSats, isFalse);
  });
}
