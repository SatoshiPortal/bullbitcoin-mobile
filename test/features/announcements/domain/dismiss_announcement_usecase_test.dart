import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/dismiss_announcement_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/repositories/announcement_dismissal_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDismissalRepository extends Mock
    implements AnnouncementDismissalRepository {}

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

    final result = await usecase.execute(AnnouncementId.payjoinPrivacy);

    expect(result, isA<Ok<void, dynamic>>());
    verify(
      () => dismissalRepository.dismiss(AnnouncementId.payjoinPrivacy),
    ).called(1);
  });

  test('returns a failure when persistence throws', () async {
    when(
      () => dismissalRepository.dismiss(any()),
    ).thenThrow(Exception('disk full'));

    final result = await usecase.execute(AnnouncementId.payjoinPrivacy);

    expect(result, isA<Err<void, dynamic>>());
  });
}
