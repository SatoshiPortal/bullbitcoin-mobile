import 'package:bb_mobile/core/wallet/domain/entity/transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:flutter/foundation.dart';

class SignTransactionUsecase {
  final WalletManagerService _walletManager;

  SignTransactionUsecase(this._walletManager);

  Future<Transaction> execute({
    required String walletId,
    required Transaction transaction,
  }) async {
    try {
      return await _walletManager.sign(walletId: walletId, tx: transaction);
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
  }
}
