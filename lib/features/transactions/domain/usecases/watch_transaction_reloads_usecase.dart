import 'dart:async';

import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';

enum TransactionHistoryUpdate { syncing, reload }

/// Coalesces the global read model without splitting its cross-wallet joins.
final class WatchTransactionReloadsUsecase {
  final WalletFacade _wallet;

  const WatchTransactionReloadsUsecase(this._wallet);

  Stream<TransactionHistoryUpdate> execute() {
    late final StreamController<TransactionHistoryUpdate> controller;
    StreamSubscription<bool>? activity;
    StreamSubscription<WalletRevisionState>? revisions;
    Timer? timer;
    var active = false;
    controller = StreamController<TransactionHistoryUpdate>(
      sync: true,
      onListen: () {
        active = _wallet.isSyncPassActive;
        activity = _wallet.watchSyncPassActivity().listen((value) {
          active = value;
          timer?.cancel();
          controller.add(
            value
                ? TransactionHistoryUpdate.syncing
                : TransactionHistoryUpdate.reload,
          );
        });
        revisions = _wallet.watchRevisions().listen((_) {
          if (active) return;
          // Direct writes and background deliveries have no foreground pass.
          // Retain the existing quiet window only for those invalidations.
          timer?.cancel();
          timer = Timer(const Duration(seconds: 3), () {
            if (!_wallet.isSyncPassActive) {
              controller.add(TransactionHistoryUpdate.reload);
            }
          });
        });
      },
      onCancel: () async {
        timer?.cancel();
        await Future.wait([
          if (activity case final subscription?) subscription.cancel(),
          if (revisions case final subscription?) subscription.cancel(),
        ]);
      },
    );
    return controller.stream;
  }
}
