import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:transactions/src/domain/entities/wallet_transaction.dart';
import 'package:transactions/src/domain/transaction_settlement.dart';
import 'package:transactions/src/domain/usecases/get_wallet_transaction_usecase.dart';
import 'package:transactions/src/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';

/// Emits the settlement transaction: its current revision once known, then
/// every later one. An unavailable read leaves the observation active.
class WatchSettlementTransactionUsecase {
  final GetWalletTransactionUsecase _get;
  final WatchWalletTransactionByTxIdUsecase _watch;

  const WatchSettlementTransactionUsecase(this._get, this._watch);

  Stream<WalletTransaction> execute(TransactionSettlementTarget target) {
    StreamSubscription<WalletTransaction>? subscription;
    late final StreamController<WalletTransaction> controller;
    var revised = false;
    controller = StreamController<WalletTransaction>(
      onListen: () {
        subscription = _watch
            .execute(walletId: target.walletId, txId: target.txId)
            .listen((transaction) {
              revised = true;
              controller.add(transaction);
            }, onError: controller.addError);
        unawaited(() async {
          final current = await _get.execute(
            txId: target.txId,
            walletId: target.walletId,
          );
          // A revision that arrived meanwhile is newer than this read.
          if (revised || controller.isClosed) return;
          if (current case Ok(:final value?)) controller.add(value);
        }());
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }
}
