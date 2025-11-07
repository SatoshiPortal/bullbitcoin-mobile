import 'dart:async';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:rxdart/rxdart.dart';

class WatchWalletTransactionByAddressUsecase {
  final WalletTransactionRepository _walletTransactionRepository;
  final WalletRepository _walletRepository;

  const WatchWalletTransactionByAddressUsecase({
    required WalletTransactionRepository walletTransactionRepository,
    required WalletRepository walletRepository,
  }) : _walletTransactionRepository = walletTransactionRepository,
       _walletRepository = walletRepository;

  Stream<WalletTransaction> execute({
    required String walletId,
    required String toAddress,
  }) {
    return _walletRepository.walletSyncFinishedStream
        .where((wallet) => wallet.id == walletId)
        .asyncMap((wallet) async {
          try {
            final txs = await _walletTransactionRepository
                .getWalletTransactions(
                  walletId: walletId,
                  toAddress: toAddress,
                );

            if (txs.isEmpty) {
              return null;
            }

            return txs.last;
          } catch (e) {
            log.severe('WatchWalletTransactionByAddressUsecase exception: $e');
            return null;
          }
        })
        .whereType<WalletTransaction>();
  }
}
