import 'package:primitives/primitives.dart';

/// Regtest Electrum endpoints, consumed only after regtest authorization.
///
/// A local stack serves plaintext Electrum on the fixed fixture ports of its
/// host; a hosted stack names a TLS endpoint per chain.
final class RegtestElectrumProfile {
  final String bitcoin;
  final String liquid;

  const RegtestElectrumProfile._({required this.bitcoin, required this.liquid});

  /// The local stack at [host].
  factory RegtestElectrumProfile({required String host}) {
    try {
      final profile = RegtestHostProfile.forNetwork(
        NetworkEnv.regtest,
        host: host,
      );
      if (host.isEmpty || profile is! LocalRegtestHost) {
        throw ArgumentError.value(host, 'host', 'Expected a local host');
      }
      return RegtestElectrumProfile.of(profile);
    } on ArgumentError {
      // The provisioning boundary models invalid configuration as a failure.
      throw const FormatException('Invalid regtest Electrum host');
    }
  }

  factory RegtestElectrumProfile.of(RegtestHostProfile profile) =>
      switch (profile) {
        LocalRegtestHost(:final host) => RegtestElectrumProfile._(
          bitcoin: 'tcp://${_authority(host)}:50000',
          liquid: 'tcp://${_authority(host)}:50001',
        ),
        HostedRegtestStack(:final endpoints) => RegtestElectrumProfile._(
          bitcoin: endpoints.electrumBitcoin.toString(),
          liquid: endpoints.electrumLiquid.toString(),
        ),
      };

  factory RegtestElectrumProfile.fromBuildEnvironment() {
    try {
      return RegtestElectrumProfile.of(
        RegtestHostProfile.forNetwork(NetworkEnv.regtest)!,
      );
    } on ArgumentError {
      throw const FormatException('Invalid regtest Electrum configuration');
    }
  }

  String endpoint({required bool isLiquid}) => isLiquid ? liquid : bitcoin;

  static String _authority(String host) =>
      host.contains(':') ? '[$host]' : host;
}
