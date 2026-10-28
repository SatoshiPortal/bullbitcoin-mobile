import '../wallet_network_key.dart';

class WalletSyncReceipt {
  final WalletNetworkKey key;
  final DateTime successfulAt;
  final String contentFingerprint;

  const WalletSyncReceipt({
    required this.key,
    required this.successfulAt,
    required this.contentFingerprint,
  });
}
