import 'dart:async';

import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';

class WatchWalletTransactionByAddressUsecase {
  final WalletTransactionRepository _walletTransactionRepository;
  final WalletFacade _walletFacade;

  const WatchWalletTransactionByAddressUsecase({
    required this._walletTransactionRepository,
    required this._walletFacade,
  });

  Stream<WalletTransaction> execute({
    required String walletId,
    required String toAddress,
  }) {
    late final StreamController<WalletTransaction> controller;
    StreamSubscription<WalletRevisionState>? revisions;
    var cancelled = false;
    var reading = false;
    var dirty = false;

    Future<void> read() async {
      dirty = true;
      if (reading) return;
      reading = true;
      try {
        while (dirty && !cancelled) {
          dirty = false;
          try {
            final txs = await _walletTransactionRepository
                .getWalletTransactions(
                  walletId: walletId,
                  toAddress: toAddress,
                );
            if (!cancelled && !dirty && txs.isNotEmpty) {
              controller.add(txs.last);
            }
          } on Exception {
            log.warning(
              'Wallet transaction revision read unavailable category=exception',
            );
          }
        }
      } finally {
        reading = false;
      }
    }

    controller = StreamController<WalletTransaction>(
      onListen: () {
        // Subscribe before the snapshot so a commit during its read is not lost.
        revisions = _walletFacade
            .watchRevisions(walletId: walletId)
            .listen((_) => unawaited(read()), onError: controller.addError);
        unawaited(read());
      },
      onCancel: () async {
        cancelled = true;
        await revisions?.cancel();
      },
    );
    return controller.stream;
  }
}
