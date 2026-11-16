/// Public local-stack configuration, consumed only after regtest authorization.
final class RegtestElectrumProfile {
  final String host;

  RegtestElectrumProfile({required this.host}) {
    final uri = Uri.tryParse('tcp://$host:50000');
    if (host.isEmpty ||
        uri == null ||
        uri.host.isEmpty ||
        uri.port != 50000 ||
        uri.userInfo.isNotEmpty ||
        uri.path.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        host.contains('/') ||
        host.contains('@') ||
        host.trim() != host) {
      throw const FormatException('Invalid regtest Electrum host');
    }
  }

  factory RegtestElectrumProfile.fromBuildEnvironment() =>
      RegtestElectrumProfile(
        host: const String.fromEnvironment(
          'BULL_REGTEST_HOST',
          defaultValue: '127.0.0.1',
        ),
      );

  String endpoint({required bool isLiquid}) =>
      'tcp://$host:${isLiquid ? 50001 : 50000}';
}
