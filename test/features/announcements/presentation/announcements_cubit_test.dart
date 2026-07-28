import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/announcements/domain/announcements_failure.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/dismiss_announcement_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/get_visible_announcements_usecase.dart';
import 'package:bb_mobile/features/announcements/presentation/announcements_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetVisibleAnnouncementsUsecase extends Mock
    implements GetVisibleAnnouncementsUsecase {}

class _MockDismissAnnouncementUsecase extends Mock
    implements DismissAnnouncementUsecase {}

Announcement _announcement() => Announcement(
  id: AnnouncementId.payjoinPrivacy,
  priority: 0,
  tone: AnnouncementTone.info,
  action: const NavigateAction(),
  dismissPolicy: const PermanentDismiss(),
);

void main() {
  late _MockGetVisibleAnnouncementsUsecase getVisible;
  late _MockDismissAnnouncementUsecase dismiss;

  setUpAll(() {
    registerFallbackValue(AnnouncementId.payjoinPrivacy);
  });

  setUp(() {
    getVisible = _MockGetVisibleAnnouncementsUsecase();
    dismiss = _MockDismissAnnouncementUsecase();
  });

  AnnouncementsCubit build() => AnnouncementsCubit(
    getVisibleAnnouncementsUsecase: getVisible,
    dismissAnnouncementUsecase: dismiss,
  );

  test(
    'dismiss records the dismissal then refreshes the visible list',
    () async {
      when(
        () => dismiss.execute(any()),
      ).thenAnswer((_) async => const Ok<void, AnnouncementsFailure>(null));
      when(() => getVisible.execute()).thenAnswer(
        (_) async =>
            Ok<List<Announcement>, AnnouncementsFailure>([_announcement()]),
      );
      final cubit = build();
      addTearDown(cubit.close);

      await cubit.dismiss(AnnouncementId.payjoinPrivacy);

      expect(cubit.state.announcements, hasLength(1));
      verify(() => dismiss.execute(AnnouncementId.payjoinPrivacy)).called(1);
      verify(() => getVisible.execute()).called(1);
    },
  );

  test('dismiss surfaces a failure in state and does not refresh', () async {
    when(() => dismiss.execute(any())).thenAnswer(
      (_) async =>
          const Err<void, AnnouncementsFailure>(AnnouncementStorageFailure()),
    );
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.dismiss(AnnouncementId.payjoinPrivacy);

    expect(cubit.state.failure, isA<AnnouncementStorageFailure>());
    verifyNever(() => getVisible.execute());
  });
}
