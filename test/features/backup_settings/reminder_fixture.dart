import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';

Wallet reminderWallet({
  int sats = 1,
  DateTime? physical,
  DateTime? encrypted,
}) => Wallet(
  origin: 'default',
  network: Network.bitcoinMainnet,
  isDefault: true,
  signers: [
    WalletSigner.single(
      masterFingerprint: 'deadbeef',
      xpubFingerprint: 'cafebabe',
      xpub: 'xpub',
      signer: SignerEntity.local,
      signerDevice: null,
    ),
  ],
  scriptType: ScriptType.bip84,
  publicDescriptor: 'wpkh(xpub/<0;1>/*)',
  balanceSat: BigInt.from(sats),
  latestPhysicalBackup: physical,
  latestEncryptedBackup: encrypted,
  isPhysicalBackupTested: physical != null,
  isEncryptedVaultTested: encrypted != null,
);
