import 'package:primitives/primitives.dart';
import 'package:announcements/src/domain/usecases/dismiss_announcement_usecase.dart';
import 'package:announcements/src/domain/entities/announcement.dart';
import 'package:announcements/setup.dart';
import 'package:announcements/src/domain/announcements_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDismissals extends Mock implements AnnouncementDismissals {}

void main() {
  late _MockDismissals dismissals;
  late DismissAnnouncementUsecase usecase;

  setUpAll(() {
    registerFallbackValue(DateTime.utc(2000));
  });

  setUp(() {
    dismissals = _MockDismissals();
    usecase = DismissAnnouncementUsecase(dismissals: dismissals);
  });

  test('records the dismissal and returns Ok', () async {
    when(() => dismissals.dismiss(any(), any()))
        .thenAnswer((_) async => const Ok(null));

    final result = await usecase.execute(AnnouncementId.payjoinPrivacy);

    expect(result, isA<Ok<void, dynamic>>());
    verify(
      () => dismissals.dismiss(
        AnnouncementId.payjoinPrivacy.name,
        any(
          that: isA<DateTime>().having((value) => value.isUtc, "isUtc", isTrue),
        ),
      ),
    ).called(1);
  });

  test('propagates the storage failure', () async {
    when(() => dismissals.dismiss(any(), any())).thenAnswer(
      (_) async => const Err(AnnouncementStorageFailure('Disk full')),
    );

    final result = await usecase.execute(AnnouncementId.payjoinPrivacy);

    expect(
      result,
      isA<Err<void, AnnouncementsFailure>>().having(
        (result) => result.failure,
        "failure",
        isA<AnnouncementStorageFailure>(),
      ),
    );
  });
}
