import 'wallet_network_key.dart';
import 'wallet_source_configuration.dart';

class WalletSourceRegistration {
  final WalletNetworkKey key;
  final String sourceKind;
  final String configurationFingerprint;
  final WalletSourceConfiguration configuration;

  const WalletSourceRegistration({
    required this.key,
    required this.sourceKind,
    required this.configurationFingerprint,
    this.configuration = const OpaqueSourceConfiguration('legacy'),
  });

  factory WalletSourceRegistration.withFingerprint({
    required WalletNetworkKey key,
    required String sourceKind,
    required WalletSourceConfiguration configuration,
  }) => WalletSourceRegistration(
    key: key,
    sourceKind: sourceKind,
    configurationFingerprint: configuration.fingerprint,
    configuration: configuration,
  );

  @override
  bool operator ==(Object other) =>
      other is WalletSourceRegistration &&
      other.key == key &&
      other.sourceKind == sourceKind &&
      other.configurationFingerprint == configurationFingerprint;
  @override
  int get hashCode => Object.hash(key, sourceKind, configurationFingerprint);

  @override
  String toString() =>
      'WalletSourceRegistration(key: $key, sourceKind: $sourceKind)';
}
