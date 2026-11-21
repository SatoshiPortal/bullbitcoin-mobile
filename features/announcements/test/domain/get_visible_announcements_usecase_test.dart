import 'package:primitives/primitives.dart';
import 'package:announcements/src/domain/entities/announcement.dart';
import 'package:announcements/src/domain/entities/announcement_catalog.dart';
import 'package:preferences/preferences_dao.dart' show PreferencesDao;
import 'package:preferences/testing.dart' show PreferencesTesting;
import 'package:announcements/src/domain/announcements_failure.dart';
import 'package:announcements/src/domain/usecases/get_visible_announcements_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPreferencesDao extends Mock implements PreferencesDao {}

void main() {
  late _MockPreferencesDao dao;
  late GetVisibleAnnouncementsUsecase usecase;
  late bool isAppUpdateRequired;

  setUp(() {
    dao = _MockPreferencesDao();
    final preferences = PreferencesTesting.fromDao(dao);
    addTearDown(preferences.close);
    isAppUpdateRequired = false;
    when(() => dao.readDismissals()).thenAnswer((_) async => const []);
    usecase = GetVisibleAnnouncementsUsecase(
      preferences.announcementDismissals,
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
    when(() => dao.readDismissals()).thenThrow(Exception('boom'));

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
