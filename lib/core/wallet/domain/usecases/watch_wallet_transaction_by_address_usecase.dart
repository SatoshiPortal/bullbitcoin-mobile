import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'dart:async';

import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';

class WatchWalletTransactionByAddressUsecase {
  final WalletTransactionRepository _walletTransactionRepository;
  final WalletRepository _walletRepository;

  const WatchWalletTransactionByAddressUsecase({
    required this._walletTransactionRepository,
    required this._walletRepository,
  });

  Stream<WalletTransaction> execute({
    required String walletId,
    required String toAddress,
  }) {
    return _walletRepository.walletSyncFinishedStream
        .where((wallet) => wallet.id == walletId)
        .asyncMap<List<WalletTransaction>>((wallet) async {
          try {
            final txs = await _walletTransactionRepository
                .getWalletTransactions(
                  walletId: walletId,
                  toAddress: toAddress,
                );

            final candidates = txs
                .where(
                  (tx) =>
                      tx.walletId == walletId &&
                      (wallet.bitcoinSyncSource !=
                              BitcoinSyncSource.compactBlockFilters ||
                          tx.isConfirmed),
                )
                .toList();
            return candidates.isEmpty ? const [] : [candidates.last];
          } catch (e) {
            log.severe(error: e, trace: StackTrace.current);
            return const [];
          }
        })
        .expand((events) => events);
  }
}
