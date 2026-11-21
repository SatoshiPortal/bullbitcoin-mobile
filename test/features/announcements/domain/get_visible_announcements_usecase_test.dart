import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement_catalog.dart';
import 'package:bb_mobile/features/announcements/domain/repositories/announcement_dismissal_repository.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/get_visible_announcements_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDismissalRepository extends Mock
    implements AnnouncementDismissalRepository {}

void main() {
  late _MockDismissalRepository dismissalRepository;
  late GetVisibleAnnouncementsUsecase usecase;
  late bool isAppUpdateRequired;

  setUp(() {
    dismissalRepository = _MockDismissalRepository();
    isAppUpdateRequired = false;
    when(() => dismissalRepository.getDismissals())
        .thenAnswer((_) async => const []);
    usecase = GetVisibleAnnouncementsUsecase(
      dismissalRepository,
      () => isAppUpdateRequired,
    );
  });

  test('the catalog contains the app update warning', () {
    expect(
      announcementCatalog.map((entry) => entry.announcement.id),
      contains(AnnouncementId.appUpdateRequired),
    );
  });

  test('returns no visible announcements before HTTP 418', () async {
    final result = await usecase.execute();

    final list = (result as Ok<List<Announcement>, dynamic>).value;
    expect(list, isEmpty);
  });

  test('returns the app update announcement after HTTP 418', () async {
    isAppUpdateRequired = true;

    final result = await usecase.execute();

    final list = (result as Ok<List<Announcement>, dynamic>).value;
    expect(list.single.id, AnnouncementId.appUpdateRequired);
    expect(list.single.tone, AnnouncementTone.warning);
  });

  test('returns a failure when the dismissals source throws', () async {
    when(() => dismissalRepository.getDismissals())
        .thenThrow(Exception('boom'));

    final result = await usecase.execute();

    expect(result, isA<Err<List<Announcement>, dynamic>>());
  });
}
