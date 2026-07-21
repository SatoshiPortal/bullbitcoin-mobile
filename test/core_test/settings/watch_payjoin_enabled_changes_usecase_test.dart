import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/watch_payjoin_enabled_changes_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late _MockSettingsRepository settingsRepository;
  late WatchPayjoinEnabledChangesUsecase usecase;

  setUp(() {
    settingsRepository = _MockSettingsRepository();
    usecase = WatchPayjoinEnabledChangesUsecase(
      settingsRepository: settingsRepository,
    );
  });

  test(
    'forwards the repository\'s payjoinEnabledChangeStream verbatim',
    () async {
      when(
        () => settingsRepository.payjoinEnabledChangeStream,
      ).thenAnswer((_) => Stream.fromIterable([true, false]));

      final emitted = await usecase.execute().toList();

      expect(emitted, [true, false]);
    },
  );
}
