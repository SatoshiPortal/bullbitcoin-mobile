import 'package:primitives/primitives.dart';

/// Public local-stack configuration, consumed only after regtest authorization.
final class RegtestElectrumProfile {
  final String host;

  RegtestElectrumProfile({required this.host}) {
    try {
      RegtestHostProfile.forNetwork(NetworkEnv.regtest, host: host);
    } on ArgumentError {
      // The provisioning boundary models invalid configuration as a failure.
      throw const FormatException('Invalid regtest Electrum host');
    }
  }

  factory RegtestElectrumProfile.fromBuildEnvironment() =>
      RegtestElectrumProfile(
        host: const String.fromEnvironment('BULL_REGTEST_HOST'),
      );

  String endpoint({required bool isLiquid}) =>
      'tcp://$host:${isLiquid ? 50001 : 50000}';
}
