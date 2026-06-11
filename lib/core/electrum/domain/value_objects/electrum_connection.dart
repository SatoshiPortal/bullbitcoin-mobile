/// A fully-resolved Electrum server connection ready to be passed to a
/// datasource (BDK / LWK / the electrum-client repository).
///
/// Produced by [ElectrumServersPort.runWithFallback]'s adapter once per
/// attempt by merging:
/// - the active server set (custom-if-set else defaults, in priority order),
/// - the persisted electrum settings (retry / timeout / stopGap / validate),
/// - the current Tor preference (socks5 proxy).
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
}
