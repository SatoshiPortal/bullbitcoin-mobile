import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_enabled_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late _MockSettingsRepository settingsRepository;
  late SetPayjoinEnabledUsecase usecase;

  setUp(() {
    settingsRepository = _MockSettingsRepository();
    when(
      () => settingsRepository.setPayjoinEnabled(any()),
    ).thenAnswer((_) async {});
    usecase = SetPayjoinEnabledUsecase(settingsRepository: settingsRepository);
  });

  test('persists enabling payjoin', () async {
    await usecase.execute(true);

    verify(() => settingsRepository.setPayjoinEnabled(true)).called(1);
  });

  test('persists disabling payjoin', () async {
    await usecase.execute(false);

    verify(() => settingsRepository.setPayjoinEnabled(false)).called(1);
  });
}
