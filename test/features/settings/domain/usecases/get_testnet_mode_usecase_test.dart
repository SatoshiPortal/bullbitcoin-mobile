import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_testnet_mode_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late _MockSettingsRepository repository;
  late GetTestnetModeUsecase usecase;

  setUp(() {
    repository = _MockSettingsRepository();
    usecase = GetTestnetModeUsecase(repository);
  });

  test('returns whether the exchange environment is testnet', () async {
    when(() => repository.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );

    final result = await usecase.execute();

    expect(result, isA<Ok<bool, SettingsFailure>>());
    expect((result as Ok<bool, SettingsFailure>).value, isTrue);
  });

  test('maps storage exceptions to a settings failure', () async {
    when(() => repository.fetch()).thenThrow(Exception('storage failed'));

    final result = await usecase.execute();

    expect(result, isA<Err<bool, SettingsFailure>>());
    expect(
      (result as Err<bool, SettingsFailure>).failure,
      isA<SettingsStorageFailure>(),
    );
  });

  test('does not turn programmer errors into recoverable failures', () async {
    when(() => repository.fetch()).thenThrow(StateError('bug'));

    expect(usecase.execute, throwsA(isA<StateError>()));
  });
}
