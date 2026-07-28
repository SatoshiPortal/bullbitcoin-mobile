import 'package:bb_mobile/core/utils/result.dart';
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

  setUp(() {
    dismissalRepository = _MockDismissalRepository();
    when(
      () => dismissalRepository.getDismissals(),
    ).thenAnswer((_) async => const []);
    usecase = GetVisibleAnnouncementsUsecase(
      dismissalRepository: dismissalRepository,
    );
  });

  test('the catalog is empty on purpose — neither the payjoin card nor the '
      'autoswap card lives on home anymore (autoswap kept its pre-existing '
      'AutoSwapWarningCard surface, as in the last release)', () {
    expect(announcementCatalog, isEmpty);
  });

  test('returns no visible announcements while the catalog is empty', () async {
    final result = await usecase.execute();

    final list = (result as Ok<List<Announcement>, dynamic>).value;
    expect(list, isEmpty);
  });

  test('returns a failure when the dismissals source throws', () async {
    when(
      () => dismissalRepository.getDismissals(),
    ).thenThrow(Exception('boom'));

    final result = await usecase.execute();

    expect(result, isA<Err<List<Announcement>, dynamic>>());
  });
}
