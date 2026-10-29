import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

Wallet publicBroadcastWallet({
  BitcoinSyncSource source = BitcoinSyncSource.electrum,
}) => Wallet(
  origin: source == BitcoinSyncSource.electrum
      ? 'public-wallet'
      : 'private-wallet',
  label: source == BitcoinSyncSource.electrum
      ? 'Public test wallet'
      : 'Private test wallet',
  network: Network.bitcoinMainnet,
  bitcoinSyncSource: source,
  xpubFingerprint: 'deadbeef',
  scriptType: ScriptType.bip84,
  xpub: 'public',
  externalPublicDescriptor: 'public/0/*',
  internalPublicDescriptor: 'public/1/*',
  signer: SignerEntity.none,
  signerDevice: null,
  balanceSat: BigInt.zero,
);
