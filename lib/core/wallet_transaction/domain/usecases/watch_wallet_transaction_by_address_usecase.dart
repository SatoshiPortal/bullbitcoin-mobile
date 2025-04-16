import 'dart:async';

import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet_transaction/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet_transaction/domain/repositories/wallet_transaction_repository.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

class WatchWalletTransactionByAddressUsecase {
  final WalletTransactionRepository _walletTransactionRepository;
  final WalletRepository _walletRepository;

  const WatchWalletTransactionByAddressUsecase({
    required WalletTransactionRepository walletTransactionRepository,
    required WalletRepository walletRepository,
  })  : _walletTransactionRepository = walletTransactionRepository,
        _walletRepository = walletRepository;

  Stream<WalletTransaction> execute({
    required String walletId,
    String? toAddress,
  }) {
    return _walletRepository.walletSyncFinishedStream
        .where((wallet) => wallet.id == walletId)
        .asyncMap(
      (wallet) async {
        try {
          debugPrint(
            'Fetching transactions'
            ' ${toAddress != null ? 'to address $toAddress' : ''}'
            ' for wallet: $walletId',
          );

          final txs = await _walletTransactionRepository.getWalletTransactions(
            walletId: walletId,
            toAddress: toAddress,
          );

          debugPrint(
            'Fetched ${txs.length} transactions'
            ' ${toAddress != null ? 'to address $toAddress' : ''}'
            ' for wallet: $walletId',
          );

          if (txs.isEmpty) {
            debugPrint(
              'No transactions found for wallet: $walletId'
              ' ${toAddress != null ? 'and address $toAddress' : ''}',
            );
            return null;
          }

          return txs.last;
        } catch (e) {
          debugPrint('WatchWalletTransactionByAddressUsecase exception: $e');
          return null;
        }
      },
    ).whereType<WalletTransaction>();
  }
}
