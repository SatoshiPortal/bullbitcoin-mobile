import 'package:primitives/primitives.dart';
import 'package:announcements/src/domain/usecases/dismiss_announcement_usecase.dart';
import 'package:announcements/src/domain/entities/announcement.dart';
import 'package:preferences/preferences_dao.dart' show PreferencesDao;
import 'package:preferences/testing.dart' show PreferencesTesting;
import 'package:announcements/src/domain/announcements_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPreferencesDao extends Mock implements PreferencesDao {}

void main() {
  late _MockPreferencesDao dao;
  late DismissAnnouncementUsecase usecase;

  setUpAll(() {
    registerFallbackValue(DateTime.utc(2000));
  });

  setUp(() {
    dao = _MockPreferencesDao();
    final preferences = PreferencesTesting.fromDao(dao);
    addTearDown(preferences.close);
    usecase = DismissAnnouncementUsecase(
      dismissals: preferences.announcementDismissals,
    );
  });

  test('records the dismissal and returns Ok', () async {
    when(() => dao.dismissAnnouncement(any(), any())).thenAnswer((_) async {});

    final result = await usecase.execute(AnnouncementId.payjoinPrivacy);

    expect(result, isA<Ok<void, dynamic>>());
    verify(
      () => dao.dismissAnnouncement(
        AnnouncementId.payjoinPrivacy.name,
        any(
          that: isA<DateTime>().having((value) => value.isUtc, "isUtc", isTrue),
        ),
      ),
    ).called(1);
  });

  test('returns a failure when persistence throws', () async {
    when(() => dao.dismissAnnouncement(any(), any()))
        .thenThrow(Exception('disk full'));

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
