import 'dart:async';

import 'package:electrum/electrum.dart';
import 'package:electrum/setup.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_active_network_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Settings extends Mock implements Preferences {}

class _Electrum extends Mock implements ElectrumDefaultsProvisioner {}

void main() {
  late _Settings repository;
  late _Electrum electrum;
  late SetActiveNetworkUsecase usecase;
  setUp(() {
    repository = _Settings();
    electrum = _Electrum();
    when(() => electrum.prepareForegroundStorage(NetworkEnv.regtest))
        .thenAnswer((_) async => const Ok(null));
    usecase = SetActiveNetworkUsecase(
      settingsRepository: repository,
      electrumSettings: electrum,
    );
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
            (_) async => Ok(
              SettingsEntity(
                environment: Environment.mainnet,
                bitcoinUnit: BitcoinUnit.sats,
                currencyCode: 'CAD',
                isSuperuser: superuser,
                isDevModeEnabled: developer,
              ),
            ),
          );
          when(() => repository.setEnvironment(environment))
              .thenAnswer((_) async => const Ok(null));
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
    when(() => repository.setEnvironment(Environment.mainnet))
        .thenAnswer((_) async => const Ok(null));
    expect(
      await usecase.execute(NetworkEnv.mainnet),
      isA<Ok<void, SettingsFailure>>(),
    );
    verify(() => repository.setEnvironment(Environment.mainnet)).called(1);
    verifyNever(() => repository.fetch());
  });

  test('read failure refuses the network change and never writes', () async {
    when(() => repository.fetch())
        .thenAnswer((_) async => const Err(PreferencesReadFailure()));
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
      (_) async => const Err(PreferencesWriteFailure('storage details')),
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
  test('regtest preparation failure leaves the network unchanged', () async {
    when(() => repository.fetch()).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
          isSuperuser: true,
          isDevModeEnabled: true,
        ),
      ),
    );
    when(() => electrum.prepareForegroundStorage(NetworkEnv.regtest))
        .thenAnswer((_) async => const Err(ElectrumSaveFailure()));
    final result = await usecase.execute(NetworkEnv.regtest);
    expect(result, isA<Err<void, SettingsFailure>>());
    expect(
      (result as Err<void, SettingsFailure>).failure,
      isA<SettingsNetworkUnavailableFailure>(),
    );
    verifyNever(() => repository.setEnvironment(Environment.regtest));
  });

  test(
    'consent revoked during provisioning prevents regtest activation',
    () async {
      var permitted = true;
      final gate = Completer<Result<void, ElectrumFailure>>();
      when(() => repository.fetch()).thenAnswer(
        (_) async => Ok(
          SettingsEntity(
            environment: Environment.mainnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'CAD',
            isSuperuser: true,
            isDevModeEnabled: permitted,
          ),
        ),
      );
      when(() => electrum.prepareForegroundStorage(NetworkEnv.regtest))
          .thenAnswer((_) => gate.future);
      final result = usecase.execute(NetworkEnv.regtest);
      await Future<void>.delayed(Duration.zero);
      permitted = false;
      gate.complete(const Ok(null));
      expect(
        (await result as Err<void, SettingsFailure>).failure,
        isA<SettingsConsentFailure>(),
      );
      verifyNever(() => repository.setEnvironment(Environment.regtest));
    },
  );
}
