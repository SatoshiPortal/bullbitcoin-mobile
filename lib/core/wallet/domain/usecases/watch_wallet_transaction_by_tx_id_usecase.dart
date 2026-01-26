import 'dart:async';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';

class WatchWalletTransactionByTxIdUsecase {
  final WalletTransactionRepository _walletTransactionRepository;
  final WalletRepository _walletRepository;

  const WatchWalletTransactionByTxIdUsecase({
    required WalletTransactionRepository walletTransactionRepository,
    required WalletRepository walletRepository,
  }) : _walletTransactionRepository = walletTransactionRepository,
       _walletRepository = walletRepository;

  Stream<WalletTransaction> execute({
    required String walletId,
    required String txId,
  }) {
    return _walletRepository.walletSyncFinishedStream
        .where((wallet) => wallet.id == walletId)
        .asyncMap((wallet) async {
          // log.info(
          //   'Fetching transaction with txId $txId'
          //   ' for wallet: $walletId',
          // );

          try {
            final tx = await _walletTransactionRepository.getWalletTransaction(
              txId,
              walletId: walletId,
            );

            // log.info(
            //   'Fetched transaction with txId $txId for wallet: $walletId',
            // );
            return tx;
          } catch (e) {
            log.severe('WatchWalletTransactionByTxIdUsecase exception: $e', trace: StackTrace.current);
            return null;
          }
        })
        .where((event) => event != null)
        .map((event) => event!);
  }
}
