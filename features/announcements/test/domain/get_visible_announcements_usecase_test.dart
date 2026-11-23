import 'package:primitives/primitives.dart';
import 'package:announcements/src/domain/entities/announcement.dart';
import 'package:announcements/src/domain/entities/announcement_catalog.dart';
import 'package:announcements/setup.dart';
import 'package:announcements/src/domain/announcements_failure.dart';
import 'package:announcements/src/domain/usecases/get_visible_announcements_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDismissals extends Mock implements AnnouncementDismissals {}

void main() {
  late _MockDismissals dismissals;
  late GetVisibleAnnouncementsUsecase usecase;
  late bool isAppUpdateRequired;

  setUp(() {
    dismissals = _MockDismissals();
    isAppUpdateRequired = false;
    when(dismissals.read).thenAnswer((_) async => const Ok([]));
    usecase = GetVisibleAnnouncementsUsecase(
      dismissals,
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

  test('propagates the storage failure', () async {
    when(dismissals.read).thenAnswer(
      (_) async => const Err(AnnouncementStorageFailure('Disk unavailable')),
    );

    final result = await usecase.execute();

    expect(
      result,
      isA<Err<List<Announcement>, AnnouncementsFailure>>().having(
        (result) => result.failure,
        "failure",
        isA<AnnouncementStorageFailure>(),
      ),
    );
  });
}
