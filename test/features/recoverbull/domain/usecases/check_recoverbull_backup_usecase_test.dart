import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/recoverbull/domain/usecases/check_recoverbull_backup_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

void main() {
  test('finds a tested RecoverBull backup for the requested seed', () async {
    final getWallets = _MockGetWalletsUsecase();
    when(
      () => getWallets.execute(onlyBitcoin: true),
    ).thenAnswer((_) async => [_wallet(fingerprint: 'deadbeef')]);
    final usecase = CheckRecoverBullBackupUsecase(getWallets);

    expect(await usecase.execute('DEADBEEF'), isTrue);
    expect(await usecase.execute('cafebabe'), isFalse);
  });
}

Wallet _wallet({required String fingerprint}) => Wallet(
  origin: 'wallet',
  network: Network.bitcoinMainnet,
  signers: [
    WalletSigner.single(
      masterFingerprint: fingerprint,
      xpubFingerprint: fingerprint,
      xpub: 'xpub',
      derivationPath: "m/84'/0'/0'",
      signer: SignerEntity.local,
      signerDevice: null,
    ),
  ],
  scriptType: ScriptType.bip84,
  publicDescriptor: 'wpkh(xpub/<0;1>/*)',
  balanceSat: BigInt.zero,
  isEncryptedVaultTested: true,
  latestEncryptedBackup: DateTime.utc(2026, 8, 28),
);
