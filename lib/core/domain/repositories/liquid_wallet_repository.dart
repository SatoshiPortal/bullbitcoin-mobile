abstract class LiquidWalletRepository {
  Future<void> sync({
    required String blockchainUrl,
    required bool validateDomain,
  });
}
