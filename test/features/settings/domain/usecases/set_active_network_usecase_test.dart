import 'package:bb_mobile/core/settings/domain/settings_store_failure.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_active_network_usecase.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Settings extends Mock implements SettingsRepository {}

void main() {
  late _Settings repository;
  late SetActiveNetworkUsecase usecase;
  setUp(() {
    repository = _Settings();
    usecase = SetActiveNetworkUsecase(settingsRepository: repository);
  });

  for (final network in [NetworkEnv.signet]) {
    test('$network refuses before any storage access', () async {
      final result = await usecase.execute(network);
      expect(result, isA<Err<void, SettingsFailure>>());
      expect(
        (result as Err<void, SettingsFailure>).failure,
        isA<SettingsNetworkUnavailableFailure>(),
      );
      expect(
        (result.failure as SettingsNetworkUnavailableFailure).network,
        network,
      );
      verifyZeroInteractions(repository);
    });
  }

  for (final (network, environment) in [
    (NetworkEnv.testnet, Environment.testnet),
    (NetworkEnv.regtest, Environment.regtest),
  ]) {
    for (final superuser in [null, false, true]) {
      for (final developer in [null, false, true]) {
        test('$network requires both flags: $superuser $developer', () async {
          when(() => repository.fetch()).thenAnswer(
            (_) async => SettingsEntity(
              environment: Environment.mainnet,
              bitcoinUnit: BitcoinUnit.sats,
              currencyCode: 'CAD',
              isSuperuser: superuser,
              isDevModeEnabled: developer,
            ),
          );
          when(
            () => repository.setEnvironment(environment),
          ).thenAnswer((_) async => const Ok(null));
          final result = await usecase.execute(network);
          expect(
            result is Ok<void, SettingsFailure>,
            superuser == true && developer == true,
          );
          if (superuser == true && developer == true) {
            verify(() => repository.setEnvironment(environment)).called(1);
          } else {
            expect(
              (result as Err<void, SettingsFailure>).failure,
              isA<SettingsConsentFailure>(),
            );
            verifyNever(() => repository.setEnvironment(environment));
          }
        });
      }
    }
  }

  test('mainnet return does not require developer flags', () async {
    when(
      () => repository.setEnvironment(Environment.mainnet),
    ).thenAnswer((_) async => const Ok(null));
    expect(
      await usecase.execute(NetworkEnv.mainnet),
      isA<Ok<void, SettingsFailure>>(),
    );
    verify(() => repository.setEnvironment(Environment.mainnet)).called(1);
    verifyNever(() => repository.fetch());
  });

  test('read exception becomes a typed failure and never writes', () async {
    when(() => repository.fetch()).thenThrow(Exception('private data'));
    final result = await usecase.execute(NetworkEnv.testnet);
    expect(
      (result as Err<void, SettingsFailure>).failure,
      isA<SettingsStorageFailure>(),
    );
    verifyNever(() => repository.setEnvironment(Environment.testnet));
  });

  test(
    'programmer errors are not converted into recoverable failures',
    () async {
      when(() => repository.fetch()).thenThrow(StateError('programmer bug'));
      await expectLater(usecase.execute(NetworkEnv.testnet), throwsStateError);
      verifyNever(() => repository.setEnvironment(Environment.testnet));
    },
  );

  test('write refusal is not reported as a successful selection', () async {
    when(() => repository.setEnvironment(Environment.mainnet)).thenAnswer(
      (_) async => const Err(SettingsStoreWriteFailure('storage details')),
    );
    final result = await usecase.execute(NetworkEnv.mainnet);
    expect(
      (result as Err<void, SettingsFailure>).failure,
      isA<SettingsStorageFailure>(),
    );
    expect(result.failure.logMessage, isNot(contains('storage details')));
  });

  test('historical settings project to primitives without renaming values', () {
    for (final environment in Environment.values) {
      final settings = SettingsEntity(
        environment: environment,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      );
      expect(settings.activeNetwork.name, environment.name);
    }
  });
}
