/// Resolved connection values for one native wallet operation.
abstract interface class WalletConnectionPort {
  String get url;
  int get retry;
  int get effectiveTimeout;
  int get stopGap;
  bool get validateDomain;
  String? get socks5;
}
