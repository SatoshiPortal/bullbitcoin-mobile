import 'dart:io';

import 'package:preferences/preferences.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/data/recoverbull_wallet_adapter.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart' show Secrets;
import 'package:secrets/testing.dart';

class _Settings extends Mock implements DeveloperEnvironmentReader {}

class _Wallets extends Mock implements WalletRepository {}

class _Create extends Mock implements CreateDefaultWalletsUsecase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'a regtest recovery request never opens the keystore on mainnet',
    () async {
      final scratch = await Directory.systemTemp.createTemp(
        'recoverbull-network-',
      );
      addTearDown(() => scratch.delete(recursive: true));
      final storage = FakeSecureStoragePlatform()..install();
      final settings = _Settings();
      when(settings.readDeveloperEnvironment).thenAnswer(
        (_) async => (
          environment: Environment.mainnet,
          isSuperuser: null,
          isDevModeEnabled: null,
        ),
      );
      final wallets = _Wallets();
      final create = _Create();
      final adapter = RecoverBullWalletAdapter(
        wallets,
        settings,
        Secrets(scratchDirectory: () async => scratch.path),
        create,
      );
      final result = await adapter.restoreDefaults(
        VaultContext(
          fingerprint: Fingerprint('73c5da0a'),
          network: BitcoinNetwork.regtest,
        ),
      );
      expect(result, isA<Err<VaultContext, RecoverBullFailure>>());
      expect(
        storage.reads,
        0,
        reason: 'Reject unsupported networks before custody access',
      );
      verifyZeroInteractions(wallets);
      verifyZeroInteractions(create);
    },
  );
  for (final production in [Environment.mainnet, Environment.testnet]) {
    for (final startsOnRegtest in [false, true]) {
      final initial = startsOnRegtest ? Environment.regtest : production;
      final target = startsOnRegtest ? production : Environment.regtest;
      test(
        '$initial to $target refuses restore before custody or wallet writes',
        () async {
          final scratch = await Directory.systemTemp.createTemp(
            'recoverbull-switch-',
          );
          addTearDown(() => scratch.delete(recursive: true));
          final storage = FakeSecureStoragePlatform()..install();
          final settings = _Settings();
          var selected = initial;
          when(settings.readDeveloperEnvironment).thenAnswer(
            (_) async => (
              environment: selected,
              isSuperuser: true,
              isDevModeEnabled: true,
            ),
          );
          final wallets = _Wallets();
          final create = _Create();
          final adapter = RecoverBullWalletAdapter(
            wallets,
            settings,
            Secrets(scratchDirectory: () async => scratch.path),
            create,
          );
          final captured = VaultContext(
            fingerprint: Fingerprint('73c5da0a'),
            network: BitcoinNetwork.fromName(initial.name),
          );
          selected = target;
          expect(
            await adapter.restoreDefaults(captured),
            isA<Err<VaultContext, RecoverBullFailure>>().having(
              (result) => result.failure,
              'failure',
              isA<VaultContextChangedFailure>(),
            ),
          );
          expect(storage.reads, 0);
          verifyZeroInteractions(wallets);
          verifyZeroInteractions(create);
        },
      );
    }
  }
  for (final enabled in [false, true]) {
    test('regtest restore requires developer access: $enabled', () async {
      final scratch = await Directory.systemTemp.createTemp(
        'recoverbull-regtest-',
      );
      addTearDown(() => scratch.delete(recursive: true));
      final storage = FakeSecureStoragePlatform()..install();
      final settings = _Settings();
      when(settings.readDeveloperEnvironment).thenAnswer(
        (_) async => (
          environment: Environment.regtest,
          isSuperuser: true,
          isDevModeEnabled: enabled,
        ),
      );
      final create = _Create();
      final adapter = RecoverBullWalletAdapter(
        _Wallets(),
        settings,
        Secrets(scratchDirectory: () async => scratch.path),
        create,
      );
      final result = await adapter.restoreDefaults(
        VaultContext(
          fingerprint: Fingerprint('73c5da0a'),
          network: BitcoinNetwork.regtest,
        ),
      );
      expect(result, isA<Err<VaultContext, RecoverBullFailure>>());
      if (enabled) {
        expect(
          storage.reads,
          greaterThan(0),
          reason: 'The supported network reaches real custody lookup',
        );
      } else {
        expect(
          storage.reads,
          0,
          reason: 'Authorization is required before custody lookup',
        );
      }
      verifyZeroInteractions(create);
    });
  }
}
