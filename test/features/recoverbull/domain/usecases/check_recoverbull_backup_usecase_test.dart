import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/recoverbull/domain/usecases/check_recoverbull_backup_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

void main() {
  test('finds the exact seed backup even when its wallet is hidden', () async {
    final getWallets = _MockGetWalletsUsecase();
    when(
      () => getWallets.execute(onlyBitcoin: true, includeHidden: true),
    ).thenAnswer(
      (_) async => [
        _wallet(fingerprint: 'deadbeef').copyWith(isHidden: true),
        _wallet(
          fingerprint: 'deadbeef',
        ).copyWith(isEncryptedVaultTested: false),
      ],
    );
    final usecase = CheckRecoverBullBackupUsecase(getWallets);

    expect(await usecase.execute('DEADBEEF'), isTrue);
    expect(await usecase.execute('cafebabe'), isFalse);
  });

  test(
    'does not apply a mixed-seed wallet backup flag to either seed',
    () async {
      final wallet = _wallet(fingerprint: 'deadbeef');
      final mixedWallet = wallet.copyWith(
        signers: [
          ...wallet.signers,
          WalletSigner.single(
            id: 'signer-1',
            descriptorKeyId: 'key-1',
            masterFingerprint: 'cafebabe',
            xpubFingerprint: '87654321',
            xpub: 'xpub-2',
            signer: SignerEntity.local,
            signerDevice: null,
          ),
        ],
      );
      final getWallets = _MockGetWalletsUsecase();
      when(
        () => getWallets.execute(onlyBitcoin: true, includeHidden: true),
      ).thenAnswer((_) async => [mixedWallet]);
      final usecase = CheckRecoverBullBackupUsecase(getWallets);

      expect(await usecase.execute('deadbeef'), isFalse);
      expect(await usecase.execute('cafebabe'), isFalse);
    },
  );
}

Wallet _wallet({required String fingerprint}) => Wallet(
  origin: 'wallet',
  network: Network.bitcoinMainnet,
  signers: [
    WalletSigner.single(
      masterFingerprint: 'cafebabe',
      xpubFingerprint: fingerprint,
      xpub: 'xpub',
      derivationPath: "m/84'/0'/0'",
      signer: SignerEntity.local,
      signerDevice: null,
    ).copyWith(localSeedFingerprint: fingerprint),
  ],
  scriptType: ScriptType.bip84,
  publicDescriptor: 'wpkh(xpub/<0;1>/*)',
  balanceSat: BigInt.zero,
  isEncryptedVaultTested: true,
  latestEncryptedBackup: DateTime.utc(2026, 8, 28),
);
