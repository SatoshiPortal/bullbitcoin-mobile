import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';

/// Fetches one wallet transaction by txid. With [sync] the lookup first
/// forces a DIRECT electrum-backed sync of the wallet (the repository's
/// sync path is not routed through the sync coordinator, so it cannot be
/// throttled away) — the way to make a transaction that was just broadcast
/// visible in the local wallet database on demand, instead of waiting for
/// the next organic sync.
class GetWalletTransactionUsecase {
  final WalletTransactionRepository _walletTransactionRepository;

  GetWalletTransactionUsecase({required this._walletTransactionRepository});

  Future<WalletTransaction?> execute({
    required String txId,
    required String walletId,
    bool sync = false,
  }) async {
    try {
      return await _walletTransactionRepository.getWalletTransaction(
        txId,
        walletId: walletId,
        sync: sync,
      );
    } catch (e) {
      throw GetWalletTransactionException(e.toString());
    }
  }
}

class GetWalletTransactionException extends BullException {
  GetWalletTransactionException(super.message);
}
