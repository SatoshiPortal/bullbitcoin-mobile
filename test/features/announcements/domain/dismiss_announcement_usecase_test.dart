import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/dismiss_announcement_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/dismiss_recoverbull_announcement_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/announcements_failure.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/repositories/announcement_dismissal_repository.dart';
import 'package:bb_mobile/features/announcements/domain/entities/recoverbull_announcement.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDismissalRepository extends Mock
    implements AnnouncementDismissalRepository {}

final class _Monitoring implements RecoverBullAttemptMonitoringController {
  final acknowledged = <RecoverBullAttemptAlert>[];

  @override
  bool get enabled => true;

  @override
  Stream<List<RecoverBullAttemptAlert>> get alerts => const Stream.empty();

  @override
  Future<List<RecoverBullAttemptAlert>> check() async => const [];

  @override
  Future<List<RecoverBullAttemptAlert>> checkOnForeground() async => const [];

  @override
  Future<void> setEnabled(bool enabled) async {}

  @override
  Future<void> acknowledge(RecoverBullAttemptAlert alert) async {
    acknowledged.add(alert);
  }

  @override
  Future<RecoverBullMonitoringStatus> status() async =>
      const RecoverBullMonitoringStatus(
        enabled: true,
        monitoredCount: 0,
        lastSuccessfulCheck: null,
      );
}

void main() {
  late _MockDismissalRepository dismissalRepository;
  late DismissAnnouncementUsecase usecase;

  setUpAll(() {
    registerFallbackValue(AnnouncementId.payjoinPrivacy);
  });

  setUp(() {
    dismissalRepository = _MockDismissalRepository();
    usecase = DismissAnnouncementUsecase(
      dismissalRepository: dismissalRepository,
    );
  });

  test('records the dismissal and returns Ok', () async {
    when(() => dismissalRepository.dismiss(any())).thenAnswer((_) async {});

    final result = await usecase.execute(_announcement());

    expect(result, isA<Ok<void, dynamic>>());
    verify(
      () => dismissalRepository.dismiss(AnnouncementId.payjoinPrivacy),
    ).called(1);
  });

  test('returns a failure when persistence throws', () async {
    when(
      () => dismissalRepository.dismiss(any()),
    ).thenThrow(Exception('disk full'));

    final result = await usecase.execute(_announcement());

    expect(result, isA<Err<void, dynamic>>());
  });

  test(
    'returns a typed failure when RecoverBull dismissal is unavailable',
    () async {
      final alert = RecoverBullAttemptAlert(
        RecoverBullAttemptAlertKind.unavailable,
      );
      final result = await usecase.execute(
        RecoverBullAnnouncement(primaryAlert: alert, sourceAlerts: [alert]),
      );

      expect(result, isA<Err<void, AnnouncementsFailure>>());
      expect(
        (result as Err<void, AnnouncementsFailure>).failure,
        isA<AnnouncementRecoverBullUnavailableFailure>(),
      );
    },
  );

  test(
    'RecoverBull dismissal acknowledges alerts without persistence',
    () async {
      final monitoring = _Monitoring();
      final alert = RecoverBullAttemptAlert.targetedLockout(
        backupReference: '12345678',
        correlationId: '1234567890abcdef',
      );
      final recoverBullDismissal = DismissRecoverBullAnnouncementUsecase(
        monitoring,
      );
      final recoverBull = RecoverBullAnnouncement(
        primaryAlert: alert,
        sourceAlerts: [alert],
      );
      usecase = DismissAnnouncementUsecase(
        dismissalRepository: dismissalRepository,
        dismissRecoverBull: recoverBullDismissal,
      );

      final result = await usecase.execute(recoverBull);

      expect(result, isA<Ok<void, AnnouncementsFailure>>());
      expect(monitoring.acknowledged, [alert]);
      verifyNever(() => dismissalRepository.dismiss(any()));
      expect(alert.backupReference, '12345678');
      expect(alert.backupReference, isNot(contains(alert.correlationId)));
    },
  );
}

Announcement _announcement() => Announcement(
  id: AnnouncementId.payjoinPrivacy,
  priority: 0,
  tone: AnnouncementTone.info,
  action: const NoAction(),
  dismissPolicy: const PermanentDismiss(),
);
