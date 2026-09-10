import 'dart:typed_data';

import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_vault_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _CreateDefaults extends Mock implements CreateDefaultWalletsUsecase {}

class _Wallets extends Mock implements WalletRepository {}

class _Wallet extends Mock implements Wallet {}

class _Settings extends Mock implements SettingsRepository {}

class _SettingsEntity extends Mock implements SettingsEntity {}

final _words = [...List.filled(11, 'abandon'), 'about'];

WalletDescriptorKey _key({
  List<String>? words,
  String passphrase = '',
  String path = "m/84'/0'/0'",
  Network network = Network.bitcoinMainnet,
}) => WalletDescriptorKey(
  id: 'key',
  signerId: 'signer',
  // Deliberately the same fingerprint for every fixture: it is not proof
  // that the complete account key belongs to the supplied seed.
  masterFingerprint: '73c5da0a',
  xpubFingerprint: '',
  xpub: Bip32Derivation.deriveXpub(
    seedBytes: Uint8List.fromList(
      bip39.Mnemonic.fromWords(
        words: words ?? _words,
        language: bip39.Language.english,
        passphrase: passphrase,
      ).seed,
    ),
    derivationPath: path,
    network: network,
  ),
  derivationPath: path,
);

_Settings _settings(Environment environment) {
  final settings = _Settings();
  final value = _SettingsEntity();
  when(() => value.environment).thenReturn(environment);
  when(() => settings.fetch()).thenAnswer((_) async => value);
  return settings;
}

void main() {
  setUpAll(() => registerFallbackValue(DateTime.utc(2026)));
  for (final createdIds in [
    <String>{},
    {'new'},
  ]) {
    test('forwards only created IDs to metadata recovery: $createdIds', () async {
      final create = _CreateDefaults();
      final wallets = _Wallets();
      final existing = _Wallet();
      final newlyCreated = _Wallet();
      when(() => existing.id).thenReturn('existing');
      when(() => existing.singleDescriptorKey).thenReturn(_key());
      when(
        () => wallets.getWallets(
          onlyDefaults: true,
          environment: Environment.mainnet,
        ),
      ).thenAnswer((_) async => [existing]);
      when(() => newlyCreated.id).thenReturn('new');
      when(
        () => create.execute(mnemonicWords: any(named: 'mnemonicWords')),
      ).thenAnswer(
        (_) async => (
          wallets: [existing, if (createdIds.isNotEmpty) newlyCreated],
          createdWalletIds: createdIds,
        ),
      );
      when(
        () => wallets.updateEncryptedBackupTime(
          time: any(named: 'time'),
          walletId: any(named: 'walletId'),
        ),
      ).thenAnswer((_) async {});
      final result =
          await RestoreVaultUsecase(
            walletRepository: wallets,
            createDefaultWalletsUsecase: create,
            settingsRepository: _settings(Environment.mainnet),
          ).execute(
            decryptedVault: DecryptedVault(
              mnemonic:
                  'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'
                      .split(' '),
            ),
          );
      expect(result, isA<Ok<List<String>, RecoverBullCoreFailure>>());
      expect(
        (result as Ok<List<String>, RecoverBullCoreFailure>).value.toSet(),
        createdIds,
      );
      verify(
        () => wallets.updateEncryptedBackupTime(
          time: any(named: 'time'),
          walletId: 'existing',
        ),
      ).called(1);
    });
  }

  for (final environment in Environment.values) {
    for (final scenario in [
      'fresh',
      'matching',
      'unrelated',
      'passphrase',
      'missing key',
      'missing path',
      'mixed defaults',
    ]) {
      test(
        '$environment: $scenario defaults are checked before mutations',
        () async {
          final create = _CreateDefaults();
          final wallets = _Wallets();
          final existing = _Wallet();
          final matching = _Wallet();
          final network = environment.isMainnet
              ? Network.bitcoinMainnet
              : Network.bitcoinTestnet;
          final path = environment.isMainnet ? "m/84'/1776'/0'" : 'm/84h/1h/0h';
          final matchingKey = _key(path: path, network: network);
          final key = switch (scenario) {
            'unrelated' || 'mixed defaults' => _key(
              words: [...List.filled(11, 'zoo'), 'wrong'],
              path: path,
              network: network,
            ),
            'passphrase' => _key(
              passphrase: 'public-test-fixture',
              path: path,
              network: network,
            ),
            'missing key' => null,
            'missing path' => WalletDescriptorKey(
              id: 'key',
              signerId: 'signer',
              masterFingerprint: '73c5da0a',
              xpubFingerprint: '',
              xpub: matchingKey.xpub,
            ),
            _ => matchingKey,
          };
          when(() => existing.id).thenReturn('existing');
          when(() => existing.singleDescriptorKey).thenReturn(key);
          when(() => matching.singleDescriptorKey).thenReturn(matchingKey);
          final defaults = [
            if (scenario == 'mixed defaults') matching,
            if (scenario != 'fresh') existing,
          ];
          when(
            () => wallets.getWallets(
              onlyDefaults: true,
              environment: environment,
            ),
          ).thenAnswer((_) async => defaults);
          when(
            () => create.execute(mnemonicWords: any(named: 'mnemonicWords')),
          ).thenAnswer(
            (_) async => (wallets: [existing], createdWalletIds: <String>{}),
          );
          when(
            () => wallets.updateEncryptedBackupTime(
              time: any(named: 'time'),
              walletId: any(named: 'walletId'),
            ),
          ).thenAnswer((_) async {});

          final result = await RestoreVaultUsecase(
            walletRepository: wallets,
            createDefaultWalletsUsecase: create,
            settingsRepository: _settings(environment),
          ).execute(decryptedVault: DecryptedVault(mnemonic: _words));

          if (scenario == 'fresh' || scenario == 'matching') {
            expect(result, isA<Ok<List<String>, RecoverBullCoreFailure>>());
            verify(() => create.execute(mnemonicWords: _words)).called(1);
            verify(
              () => wallets.updateEncryptedBackupTime(
                time: any(named: 'time'),
                walletId: 'existing',
              ),
            ).called(1);
          } else {
            expect(result, isA<Err<List<String>, RecoverBullCoreFailure>>());
            expect(
              (result as Err<List<String>, RecoverBullCoreFailure>).failure,
              isA<InvalidVaultFileFailure>(),
            );
            verifyNever(
              () => create.execute(mnemonicWords: any(named: 'mnemonicWords')),
            );
            verifyNever(
              () => wallets.updateEncryptedBackupTime(
                time: any(named: 'time'),
                walletId: any(named: 'walletId'),
              ),
            );
          }
        },
      );
    }
  }
}
