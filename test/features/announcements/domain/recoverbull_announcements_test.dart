import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/watch_recoverbull_announcements_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/dismiss_recoverbull_announcement_usecase.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lockout supersedes suspicious activity for the same backup', () async {
    final suspicious = RecoverBullAttemptAlert.suspiciousActivity(
      backupReference: 'backup-a',
      correlationId: 'digest-a',
      observedTotal: 3,
      expectedTotal: 1,
      windowStartedAt: DateTime.utc(2026, 1, 1),
    );
    final lockout = RecoverBullAttemptAlert.targetedLockout(
      backupReference: 'backup-a',
      correlationId: 'digest-a',
    );

    final announcements = await WatchRecoverBullAnnouncementsUsecase(
      _Controller([suspicious, lockout]),
    ).execute().first;

    expect(announcements, hasLength(1));
    expect(announcements.single.id, AnnouncementId.recoverBullTargetedActivity);
    expect(announcements.single.sourceAlerts, hasLength(2));
    expect(suspicious.identity, isNot(lockout.identity));
    expect(suspicious.correlationId, lockout.correlationId);
  });

  test('different backups remain separate carousel pages', () async {
    final alerts = [
      RecoverBullAttemptAlert.targetedLockout(
        backupReference: 'backup-a',
        correlationId: 'digest-a',
      ),
      RecoverBullAttemptAlert.suspiciousActivity(
        backupReference: 'backup-b',
        correlationId: 'digest-b',
        observedTotal: 2,
        expectedTotal: 1,
        windowStartedAt: DateTime.utc(2026, 1, 1),
      ),
    ];

    final announcements = await WatchRecoverBullAnnouncementsUsecase(
      _Controller(alerts),
    ).execute().first;

    expect(announcements, hasLength(2));
    expect(
      announcements.map((announcement) => announcement.stableKey),
      containsAll(<String>['recoverbull:digest-a', 'recoverbull:digest-b']),
    );
  });

  test(
    'opaque identities keep same-prefix digests on separate pages',
    () async {
      final alerts = [
        RecoverBullAttemptAlert.targetedLockout(
          backupReference: 'deadbeef',
          correlationId: 'deadbeef00000001',
        ),
        RecoverBullAttemptAlert.targetedLockout(
          backupReference: 'deadbeef',
          correlationId: 'deadbeef00000002',
        ),
      ];

      final announcements = await WatchRecoverBullAnnouncementsUsecase(
        _Controller(alerts),
      ).execute().first;

      expect(announcements, hasLength(2));
      expect(
        announcements.map((announcement) => announcement.stableKey),
        containsAll(<String>[
          'recoverbull:deadbeef00000001',
          'recoverbull:deadbeef00000002',
        ]),
      );
    },
  );

  test('maps every RecoverBull alert kind to a page', () async {
    final announcements = await WatchRecoverBullAnnouncementsUsecase(
      _Controller([
        for (final kind in RecoverBullAttemptAlertKind.values)
          RecoverBullAttemptAlert(kind),
      ]),
    ).execute().first;

    expect(announcements, hasLength(4));
    expect(
      announcements.map((announcement) => announcement.primaryAlert.kind),
      containsAll(RecoverBullAttemptAlertKind.values),
    );
  });

  test(
    'dismissing a consolidated page acknowledges every source alert',
    () async {
      final suspicious = RecoverBullAttemptAlert.suspiciousActivity(
        backupReference: 'backup-a',
        correlationId: 'digest-a',
        observedTotal: 3,
        expectedTotal: 1,
        windowStartedAt: DateTime.utc(2026, 1, 1),
      );
      final lockout = RecoverBullAttemptAlert.targetedLockout(
        backupReference: 'backup-a',
        correlationId: 'digest-a',
      );
      final controller = _Controller([suspicious, lockout]);
      final page = (await WatchRecoverBullAnnouncementsUsecase(
        controller,
      ).execute().first).single;

      await DismissRecoverBullAnnouncementUsecase(controller).execute(page);

      expect(controller.acknowledged, [suspicious, lockout]);
    },
  );
}

final class _Controller implements RecoverBullAttemptMonitoringController {
  final List<RecoverBullAttemptAlert> value;
  final acknowledged = <RecoverBullAttemptAlert>[];
  _Controller(this.value);
  @override
  Stream<List<RecoverBullAttemptAlert>> get alerts async* {
    yield value;
  }

  @override
  Future<List<RecoverBullAttemptAlert>> check() async => value;
  @override
  Future<List<RecoverBullAttemptAlert>> checkOnForeground() async => value;
  @override
  Future<void> setEnabled(bool enabled) async {}
  @override
  Future<void> acknowledge(RecoverBullAttemptAlert alert) async {
    acknowledged.add(alert);
  }

  @override
  bool get enabled => true;
  @override
  Future<RecoverBullMonitoringStatus> status() async =>
      const RecoverBullMonitoringStatus(
        enabled: true,
        monitoredCount: 1,
        lastSuccessfulCheck: null,
      );
}
