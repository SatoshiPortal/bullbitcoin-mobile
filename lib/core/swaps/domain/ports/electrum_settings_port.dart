class SwapElectrumServerConfig {
  final String url;
  final bool tls;
  final bool validateDomain;
  final int timeout;

  const SwapElectrumServerConfig({
    required this.url,
    required this.tls,
    required this.validateDomain,
    required this.timeout,
  });
}

abstract class ElectrumSettingsPort {
  Future<SwapElectrumServerConfig?> getPreferredServer({
    required bool isTestnet,
    required bool isLiquid,
  });
}
