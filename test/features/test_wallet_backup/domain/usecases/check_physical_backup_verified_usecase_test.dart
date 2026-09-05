import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/check_physical_backup_verified_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

void main() {
  test(
    'finds a verified local wallet for the exact seed fingerprint',
    () async {
      final getWallets = _MockGetWalletsUsecase();
      when(() => getWallets.execute(onlyBitcoin: true)).thenAnswer(
        (_) async => [
          _wallet(fingerprint: 'deadbeef', isPhysicalBackupTested: true),
        ],
      );
      final usecase = CheckPhysicalBackupVerifiedUsecase(getWallets);

      expect(await usecase.execute('DEADBEEF'), isTrue);
      expect(await usecase.execute('cafebabe'), isFalse);
    },
  );
}

Wallet _wallet({
  required String fingerprint,
  required bool isPhysicalBackupTested,
}) => Wallet(
  origin: fingerprint,
  network: Network.bitcoinMainnet,
  signers: [
    WalletSigner.single(
      masterFingerprint: fingerprint,
      xpubFingerprint: '01234567',
      xpub: 'xpub',
      derivationPath: "m/84'/0'/0'",
      signer: SignerEntity.local,
      signerDevice: null,
    ),
  ],
  scriptType: ScriptType.bip84,
  publicDescriptor: 'wpkh(xpub/<0;1>/*)',
  balanceSat: BigInt.zero,
  isPhysicalBackupTested: isPhysicalBackupTested,
);
