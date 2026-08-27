/// A fully-resolved Electrum server connection ready to be passed to a
/// datasource (BDK / LWK / the electrum-client repository).
///
/// Produced by [ElectrumServersPort.runWithFallback]'s adapter once per
/// attempt by merging:
/// - the active server set (custom-if-set else defaults, in priority order),
/// - the persisted electrum settings (retry / timeout / stopGap / validate),
/// - the proxy this server should go through, if any.
///
/// [socks5] is a `host:port` string rather than a typed endpoint because that
/// is the shape its consumers take: BDK's Electrum client accepts a string,
/// and the advanced options let the user type one by hand.
///
/// [isCustom] is carried only so the executor's error reporting can tell the
/// caller which tier was exhausted — datasources should not branch on it.
class ElectrumConnection {
  final String url;
  final int retry;
  final int timeout;
  final int stopGap;
  final bool validateDomain;
  final String? socks5;
  final bool isCustom;

  const ElectrumConnection({
    required this.url,
    required this.retry,
    required this.timeout,
    required this.stopGap,
    required this.validateDomain,
    required this.isCustom,
    this.socks5,
  });

  ElectrumConnection withSocks5(String? socks5) => ElectrumConnection(
    url: url,
    retry: retry,
    timeout: timeout,
    stopGap: stopGap,
    validateDomain: validateDomain,
    isCustom: isCustom,
    socks5: socks5,
  );
}
