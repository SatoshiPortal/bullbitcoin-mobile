import 'wallet_network_key.dart';

class WalletSourceRegistration {
  final WalletNetworkKey key;
  final String sourceKind;
  final String configurationFingerprint;

  const WalletSourceRegistration({
    required this.key,
    required this.sourceKind,
    required this.configurationFingerprint,
  });

  @override
  bool operator ==(Object other) =>
      other is WalletSourceRegistration &&
      other.key == key &&
      other.sourceKind == sourceKind &&
      other.configurationFingerprint == configurationFingerprint;
  @override
  int get hashCode => Object.hash(key, sourceKind, configurationFingerprint);
}
