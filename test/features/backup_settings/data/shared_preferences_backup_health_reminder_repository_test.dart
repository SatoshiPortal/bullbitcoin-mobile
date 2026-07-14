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
    expect(record.highestHandledBalanceTier, BackupBalanceTier.none);
    expect(record.pendingActionStartedAt, isNull);
  });

  test(
    'round-trips acknowledgement, tiers, and pending action in UTC',
    () async {
      final acknowledgedAt = DateTime.parse('2026-07-14T08:00:00-04:00');
      final pendingAt = DateTime.parse('2026-07-15T08:00:00-04:00');

      final saved = await repository.save(
        BackupHealthReminderRecord(
          masterFingerprint: fingerprint,
          lastAcknowledgedAt: acknowledgedAt,
          highestHandledBalanceTier: BackupBalanceTier.oneMillion,
          pendingActionStartedAt: pendingAt,
          pendingActionBalanceTier: BackupBalanceTier.tenMillion,
        ),
      );
      expect(saved, isA<Ok>());

      final record = await fetchRecord();
      expect(record.lastAcknowledgedAt, acknowledgedAt.toUtc());
      expect(record.highestHandledBalanceTier, BackupBalanceTier.oneMillion);
      expect(record.pendingActionStartedAt, pendingAt.toUtc());
      expect(record.pendingActionBalanceTier, BackupBalanceTier.tenMillion);
    },
  );

  test('corrupt state fails safely to an empty record', () async {
    SharedPreferences.setMockInitialValues({
      'backup_health_reminder_v1_$fingerprint': '{not-json',
    });

    final record = await fetchRecord();

    expect(record.masterFingerprint, fingerprint);
    expect(record.lastAcknowledgedAt, isNull);
    expect(record.highestHandledBalanceTier, BackupBalanceTier.none);
  });

  test('wrongly typed state fails safely to an empty record', () async {
    SharedPreferences.setMockInitialValues({
      'backup_health_reminder_v1_$fingerprint':
          '{"version":"one","lastAcknowledgedAt":null}',
    });

    final record = await fetchRecord();

    expect(record.masterFingerprint, fingerprint);
    expect(record.lastAcknowledgedAt, isNull);
    expect(record.highestHandledBalanceTier, BackupBalanceTier.none);
  });

  test('non-object state fails safely to an empty record', () async {
    SharedPreferences.setMockInitialValues({
      'backup_health_reminder_v1_$fingerprint': '[]',
    });

    final record = await fetchRecord();

    expect(record.masterFingerprint, fingerprint);
    expect(record.lastAcknowledgedAt, isNull);
    expect(record.highestHandledBalanceTier, BackupBalanceTier.none);
  });
}
