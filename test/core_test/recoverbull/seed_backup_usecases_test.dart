import 'dart:convert';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/update_latest_encrypted_backup_usecase.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRecoverBullRepository extends Mock
    implements RecoverBullRepository {}

class _MockSeedRepository extends Mock implements SeedRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockEncryptedVault extends Mock implements EncryptedVault {}

class _WalletRepository extends Fake implements WalletRepository {
  final List<Wallet> wallets;
  final updatedBackupTimes = <String, DateTime?>{};

  _WalletRepository(this.wallets);

  @override
  Future<List<Wallet>> getWallets({
    Environment? environment,
    bool? onlyDefaults,
    bool? onlyBitcoin,
    bool? onlyLiquid,
    bool sync = false,
  }) async => wallets
      .where(
        (wallet) =>
            (onlyDefaults != true || wallet.isDefault) &&
            (onlyBitcoin != true || wallet.isBitcoin) &&
            (onlyLiquid != true || wallet.isLiquid) &&
            (environment == null || wallet.isTestnet == environment.isTestnet),
      )
      .toList();

  @override
  Future<void> updateEncryptedBackupTime({
    required String walletId,
    required DateTime? time,
  }) async {
    updatedBackupTimes[walletId] = time;
  }
}

void main() {
  final seed =
      SeedModel.mnemonic(
            mnemonicWords:
                'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'
                    .split(' '),
          ).toEntity()
          as MnemonicSeed;
  final otherSeed =
      SeedModel.mnemonic(
            mnemonicWords:
                'legal winner thank year wave sausage worth useful legal winner thank yellow'
                    .split(' '),
          ).toEntity()
          as MnemonicSeed;
  final restored = _wallet('restored', seed.masterFingerprint, protected: true);
  final defaultWallet = _wallet(
    'default',
    otherSeed.masterFingerprint,
    isDefault: true,
  );
  final mixedWallet = restored.copyWith(
    origin: 'mixed',
    signers: [
      ...restored.signers,
      WalletSigner.single(
        id: 'signer-1',
        descriptorKeyId: 'key-1',
        masterFingerprint: otherSeed.masterFingerprint,
        xpubFingerprint: '87654321',
        xpub: 'xpub-2',
        signer: SignerEntity.local,
        signerDevice: null,
      ),
    ],
  );

  for (final requested in [false, true]) {
    test(
      'creates a backup for the ${requested ? 'requested nondefault' : 'default'} seed',
      () async {
        final wallets = _WalletRepository([
          mixedWallet,
          defaultWallet,
          restored,
        ]);
        final seeds = _MockSeedRepository();
        final recoverBull = _MockRecoverBullRepository();
        final expectedSeed = requested ? seed : otherSeed;
        final expectedWallet = requested ? restored : defaultWallet;
        when(
          () => seeds.get(expectedSeed.masterFingerprint),
        ).thenAnswer((_) async => expectedSeed);
        when(
          () => recoverBull.createVault(
            vaultKey: any(named: 'vaultKey'),
            plaintext: any(named: 'plaintext'),
            derivationPath: any(named: 'derivationPath'),
          ),
        ).thenReturn(Ok(_MockEncryptedVault()));

        final result =
            await CreateEncryptedVaultUsecase(
              recoverBullRepository: recoverBull,
              seedRepository: seeds,
              walletRepository: wallets,
            ).execute(
              fingerprint: requested
                  ? seed.masterFingerprint.toUpperCase()
                  : null,
            );

        final walletId = switch (result) {
          Ok(:final value) => value.walletId,
          Err() => fail('Could not create the selected seed backup'),
        };
        expect(walletId, expectedWallet.id);
        final plaintext =
            verify(
                  () => recoverBull.createVault(
                    vaultKey: any(named: 'vaultKey'),
                    plaintext: captureAny(named: 'plaintext'),
                    derivationPath: any(named: 'derivationPath'),
                  ),
                ).captured.single
                as String;
        final backup = DecryptedVault.fromJson(
          jsonDecode(plaintext) as Map<String, dynamic>,
        );
        expect(backup.masterFingerprint, expectedSeed.masterFingerprint);
        expect(backup.mnemonic, expectedSeed.mnemonicWords);
      },
    );
  }

  test(
    'testing a backup marks matching nondefault wallets and preserves other seeds',
    () async {
      final wallets = _WalletRepository([mixedWallet, defaultWallet, restored]);
      final settings = _MockSettingsRepository();
      when(settings.fetch).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      );

      final result =
          await UpdateLatestEncryptedVaultTestUsecase(
            walletRepository: wallets,
            settingsRepository: settings,
          ).execute(
            decryptedVault: DecryptedVault(
              mnemonic: seed.mnemonicWords,
              masterFingerprint: defaultWallet.masterFingerprint,
            ),
          );

      expect(result, isA<Ok>());
      expect(wallets.updatedBackupTimes.keys, [restored.id]);
      expect(wallets.updatedBackupTimes[restored.id], isNotNull);
    },
  );
}

Wallet _wallet(
  String id,
  String fingerprint, {
  bool isDefault = false,
  bool protected = false,
}) => Wallet(
  origin: id,
  network: Network.bitcoinMainnet,
  isDefault: isDefault,
  signers: [
    WalletSigner.single(
      masterFingerprint: protected ? 'cafebabe' : fingerprint,
      xpubFingerprint: '12345678',
      xpub: 'xpub',
      signer: SignerEntity.local,
      signerDevice: null,
    ).copyWith(localSeedFingerprint: protected ? fingerprint : null),
  ],
  scriptType: ScriptType.bip84,
  publicDescriptor: 'wpkh(xpub/<0;1>/*)',
  balanceSat: BigInt.zero,
);
