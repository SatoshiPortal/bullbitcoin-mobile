import 'dart:async';

import 'package:bb_mobile/core/wallet_transaction/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet_transaction/domain/repositories/wallet_transaction_repository.dart';
import 'package:flutter/material.dart';

class WatchWalletTransactionByAddressUsecase {
  final WalletTransactionRepository _walletTransactionRepository;

  const WatchWalletTransactionByAddressUsecase({
    required WalletTransactionRepository walletTransactionRepository,
  }) : _walletTransactionRepository = walletTransactionRepository;

  Stream<WalletTransaction> execute({
    required String walletId,
    String? toAddress,
    Duration pollInterval = const Duration(seconds: 5),
  }) {
    final controller = StreamController<WalletTransaction>();
    bool isCancelled = false;

    Future<void> pollingLoop() async {
      while (!isCancelled) {
        try {
          debugPrint(
            'Fetching transactions to address $toAddress for wallet: $walletId',
          );
          final txs = await _walletTransactionRepository.getWalletTransactions(
            walletId: walletId,
            toAddress: toAddress,
            sync: true,
          );
          debugPrint(
            'Fetched ${txs.length} transactions to address $toAddress for wallet: $walletId',
          );

          final tx = txs.isNotEmpty
              ? txs.firstWhere(
                  (tx) => tx.status == WalletTransactionStatus.pending,
                  orElse: () => txs.last,
                )
              : null;

          if (tx != null) {
            controller.add(tx);
          }
        } catch (e, stack) {
          debugPrint('Error fetching transactions: $e');
          if (controller.isClosed) {
            debugPrint('Controller is closed, not adding error');
          } else {
            controller.addError(e, stack);
          }
        }

        await Future.delayed(pollInterval);
      }
    }

    // Start loop
    pollingLoop();

    controller.onCancel = () async {
      isCancelled = true;
      await controller.close();
    };

    return controller.stream;
  }
}
