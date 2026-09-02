import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/update_latest_encrypted_backup_usecase.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Wallets extends Mock implements WalletRepository {}

class _Settings extends Mock implements SettingsRepository {}

void main() {
  late _Wallets wallets;
  late _Settings settings;
  late UpdateLatestEncryptedVaultTestUsecase usecase;

  setUp(() {
    wallets = _Wallets();
    settings = _Settings();
    usecase = UpdateLatestEncryptedVaultTestUsecase(
      walletRepository: wallets,
      settingsRepository: settings,
    );
    when(() => settings.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
  });

  test(
    'rejects a vault for another seed without changing test history',
    () async {
      when(
        () => wallets.getWallets(
          onlyDefaults: true,
          environment: Environment.mainnet,
        ),
      ).thenAnswer((_) async => [_wallet(masterFingerprint: '00000000')]);

      final result = await usecase.execute(decryptedVault: _vault());

      expect(result, isA<Err<Null, RecoverBullCoreFailure>>());
      expect((result as Err).failure, isA<InvalidVaultFileFailure>());
      verifyNever(
        () => wallets.updateEncryptedBackupTime(
          time: any(named: 'time'),
          walletId: any(named: 'walletId'),
        ),
      );
    },
  );
}

DecryptedVault _vault() => const DecryptedVault(
  mnemonic: [
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'about',
  ],
);

Wallet _wallet({required String masterFingerprint}) => Wallet(
  origin: 'wallet-id',
  network: Network.bitcoinMainnet,
  isDefault: true,
  masterFingerprint: masterFingerprint,
  xpubFingerprint: masterFingerprint,
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);
