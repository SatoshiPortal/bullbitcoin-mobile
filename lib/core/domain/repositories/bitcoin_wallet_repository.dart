abstract class BitcoinWalletRepository {
  Future<void> sync({
    required String blockchainUrl,
    String? socks5,
    required int retry,
    int? timeout,
    required BigInt stopGap,
    required bool validateDomain,
  });
}
