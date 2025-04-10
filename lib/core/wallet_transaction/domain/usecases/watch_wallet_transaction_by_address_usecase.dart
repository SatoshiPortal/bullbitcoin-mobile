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
    Duration pollInterval = const Duration(seconds: 15),
  }) {
    final controller = StreamController<WalletTransaction>();
    Timer? timer;

    Future<void> fetchAndEmit() async {
      try {
        debugPrint(
            'Fetching transactions to address $toAddress for wallet: $walletId');
        final txs = await _walletTransactionRepository.getWalletTransactions(
          walletId: walletId,
          toAddress: toAddress,
          sync: true,
        );
        debugPrint(
            'Fetched ${txs.length} transactions to address $toAddress for wallet: $walletId');

        // If more than one, get the pending one if exists, else get the last one
        final tx = txs.isNotEmpty
            ? txs.firstWhere(
                (tx) => tx.status == WalletTransactionStatus.pending,
                orElse: () => txs.last,
              )
            : null;

        if (tx == null) {
          return;
        }

        controller.add(tx);
      } catch (e, stack) {
        controller.addError(e, stack);
      }
    }

    // Start immediately
    fetchAndEmit();

    // Schedule repeated polling
    timer = Timer.periodic(pollInterval, (_) => fetchAndEmit());

    // Clean up when no one is listening anymore
    controller.onCancel = () {
      timer?.cancel();
      controller.close();
    };

    return controller.stream;
  }
}
