class ElectrumServer {
  final String url;
  final int priority;
  final int retry;
  final int timeout;
  final int stopGap;
  final bool validateDomain;
  final String? socks5;
  final bool isCustom;

  const ElectrumServer({
    required this.url,
    required this.priority,
    required this.retry,
    required this.timeout,
    required this.stopGap,
    required this.validateDomain,
    this.socks5,
    required this.isCustom,
  });
}
