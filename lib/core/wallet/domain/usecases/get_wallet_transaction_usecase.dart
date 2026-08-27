import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';

/// Fetches one wallet transaction by txid. With [sync] the lookup first
/// forces a DIRECT electrum-backed sync of the wallet (the repository's
/// sync path is not routed through the sync coordinator, so it cannot be
/// throttled away) — the way to make a transaction that was just broadcast
/// visible in the local wallet database on demand, instead of waiting for
/// the next organic sync.
class GetWalletTransactionUsecase {
  final WalletTransactionRepository _walletTransactionRepository;

  GetWalletTransactionUsecase({required this._walletTransactionRepository});

  @useResult
  Future<Result<WalletTransaction?, WalletTransactionLookupFailure>> execute({
    required String txId,
    required String walletId,
    bool sync = false,
  }) async {
    try {
      final transaction = await _walletTransactionRepository
          .getWalletTransaction(txId, walletId: walletId, sync: sync);
      return Ok(transaction);
    } catch (e) {
      return Err(WalletTransactionLookupFailure(e.toString()));
    }
  }
}
