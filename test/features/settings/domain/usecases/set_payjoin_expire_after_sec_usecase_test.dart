import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_expire_after_sec_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late _MockSettingsRepository settingsRepository;
  late SetPayjoinExpireAfterSecUsecase usecase;

  setUp(() {
    settingsRepository = _MockSettingsRepository();
    when(
      () => settingsRepository.setPayjoinExpireAfterSec(any()),
    ).thenAnswer((_) async {});
    usecase = SetPayjoinExpireAfterSecUsecase(
      settingsRepository: settingsRepository,
    );
  });

  test('persists a value within bounds', () async {
    await usecase.execute(3600);

    verify(() => settingsRepository.setPayjoinExpireAfterSec(3600)).called(1);
  });

  test('throws and never persists below the minimum bound', () async {
    await expectLater(
      () => usecase.execute(PayjoinConstants.minExpireAfterSec - 1),
      throwsArgumentError,
    );

    verifyNever(() => settingsRepository.setPayjoinExpireAfterSec(any()));
  });

  test('throws and never persists above the maximum bound', () async {
    await expectLater(
      () => usecase.execute(PayjoinConstants.maxExpireAfterSec + 1),
      throwsArgumentError,
    );

    verifyNever(() => settingsRepository.setPayjoinExpireAfterSec(any()));
  });
}
