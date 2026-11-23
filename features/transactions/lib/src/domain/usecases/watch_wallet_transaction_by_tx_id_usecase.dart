import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:transactions/src/domain/entities/wallet_transaction.dart';
import 'package:transactions/src/domain/repositories/wallet_transaction_repository.dart';

import 'wallet_history_events.dart';

class WatchWalletTransactionByTxIdUsecase {
  final WalletTransactionRepository _walletTransactionRepository;
  final WalletHistoryEvents _walletFacade;

  const WatchWalletTransactionByTxIdUsecase({
    required this._walletTransactionRepository,
    required this._walletFacade,
  });

  Stream<WalletTransaction> execute({
    required String walletId,
    required String txId,
  }) => _walletFacade
      .watchRevisions(walletId: walletId)
      .asyncMap((_) async {
        try {
          final result = await _walletTransactionRepository
              .getWalletTransaction(txId, walletId: walletId);
          return switch (result) {
            Ok(:final value) => value,
            Err() => null,
          };
        } on Exception {
          log.warning(
            'Wallet transaction revision read unavailable category=exception',
          );
          return null;
        }
      })
      .where((transaction) => transaction != null)
      .cast<WalletTransaction>();
}
