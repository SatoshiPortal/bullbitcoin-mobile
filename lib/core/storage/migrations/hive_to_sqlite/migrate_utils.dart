import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_wallet.dart'
    show BBNetwork, BaseWalletType, Wallet;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart'
    show Network, ScriptType;
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart'
    show WalletMetadataService;

String computeOriginFromOldWallet(Wallet wallet) {
  return WalletMetadataService.encodeOrigin(
    fingerprint: wallet.sourceFingerprint,
    network: getNetworkFromOldWallet(wallet),
    scriptType: ScriptType.fromName(wallet.scriptType.name),
  );
}

Network getNetworkFromOldWallet(Wallet wallet) {
  final bbNetwork = wallet.network;
  final bbWalletType = wallet.baseWalletType;

  Network? network;
  if (bbNetwork == BBNetwork.Mainnet &&
      bbWalletType == BaseWalletType.Bitcoin) {
    network = Network.bitcoinMainnet;
  } else if (bbNetwork == BBNetwork.Mainnet &&
      bbWalletType == BaseWalletType.Liquid) {
    network = Network.liquidMainnet;
  } else if (bbNetwork == BBNetwork.Testnet &&
      bbWalletType == BaseWalletType.Bitcoin) {
    network = Network.bitcoinTestnet;
  } else if (bbNetwork == BBNetwork.Testnet &&
      bbWalletType == BaseWalletType.Liquid) {
    network = Network.liquidTestnet;
  } else {
    final msg = 'Unsupported network: $bbNetwork $bbWalletType';
    throw Exception(msg);
  }

  return network;
}
