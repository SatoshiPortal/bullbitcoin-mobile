import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_wallet.dart'
    show OldBBNetwork, OldBaseWalletType, OldWallet;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart'
    show Network, ScriptType;
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart'
    show WalletMetadataService;

String computeOriginFromOldWallet(OldWallet wallet) {
  return WalletMetadataService.encodeOrigin(
    fingerprint: wallet.sourceFingerprint,
    network: getNetworkFromOldWallet(wallet),
    scriptType: ScriptType.fromName(wallet.scriptType.name),
  );
}

Network getNetworkFromOldWallet(OldWallet wallet) {
  final bbNetwork = wallet.network;
  final bbWalletType = wallet.baseWalletType;

  Network? network;
  if (bbNetwork == OldBBNetwork.Mainnet &&
      bbWalletType == OldBaseWalletType.Bitcoin) {
    network = Network.bitcoinMainnet;
  } else if (bbNetwork == OldBBNetwork.Mainnet &&
      bbWalletType == OldBaseWalletType.Liquid) {
    network = Network.liquidMainnet;
  } else if (bbNetwork == OldBBNetwork.Testnet &&
      bbWalletType == OldBaseWalletType.Bitcoin) {
    network = Network.bitcoinTestnet;
  } else if (bbNetwork == OldBBNetwork.Testnet &&
      bbWalletType == OldBaseWalletType.Liquid) {
    network = Network.liquidTestnet;
  } else {
    final msg = 'Unsupported network: $bbNetwork $bbWalletType';
    throw Exception(msg);
  }

  return network;
}
