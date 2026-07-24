import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_min_amount_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late _MockSettingsRepository settingsRepository;
  late SetPayjoinMinAmountUsecase usecase;

  setUp(() {
    settingsRepository = _MockSettingsRepository();
    when(
      () => settingsRepository.setPayjoinMinAmountSat(any()),
    ).thenAnswer((_) async {});
    usecase = SetPayjoinMinAmountUsecase(
      settingsRepository: settingsRepository,
    );
  });

  test('persists a value within bounds', () async {
    await usecase.execute(50000);

    verify(() => settingsRepository.setPayjoinMinAmountSat(50000)).called(1);
  });

  test('persists the exact lower bound', () async {
    await usecase.execute(PayjoinConstants.minMinAmountSat);

    verify(
      () => settingsRepository.setPayjoinMinAmountSat(
        PayjoinConstants.minMinAmountSat,
      ),
    ).called(1);
  });

  test('persists the exact upper bound', () async {
    await usecase.execute(PayjoinConstants.maxMinAmountSat);

    verify(
      () => settingsRepository.setPayjoinMinAmountSat(
        PayjoinConstants.maxMinAmountSat,
      ),
    ).called(1);
  });

  test('throws and never persists below the minimum bound', () async {
    await expectLater(
      () => usecase.execute(PayjoinConstants.minMinAmountSat - 1),
      throwsArgumentError,
    );

    verifyNever(() => settingsRepository.setPayjoinMinAmountSat(any()));
  });

  test('throws and never persists above the maximum bound', () async {
    await expectLater(
      () => usecase.execute(PayjoinConstants.maxMinAmountSat + 1),
      throwsArgumentError,
    );

    verifyNever(() => settingsRepository.setPayjoinMinAmountSat(any()));
  });
}
