/*class GetWalletTransactionsUseCase {
  final WalletManager _manager;

  GetWalletTransactionsUseCase(
      {required WalletManager walletManager})
      : _manager = walletManager;

  Future<List<Transaction>> execute(
    String walletId, {
    int? offset,
    int? limit,
  }) async {
    final walletRepository = _manager.getRepository(walletId);

    if (walletRepository == null) {
      return [];
    }

    return await walletRepository.getTransactions(offset: offset, limit: limit);
  }
}*/
