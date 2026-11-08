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
    StreamSubscription<void>? finishes;
    Timer? timer;
    var active = false;
    var completionPending = false;
    controller = StreamController<TransactionHistoryUpdate>(
      sync: true,
      onListen: () {
        active = _wallet.isSyncPassActive;
        activity = _wallet.watchSyncPassActivity().listen((value) {
          active = value;
          timer?.cancel();
          completionPending = !value;
          if (value) {
            controller.add(TransactionHistoryUpdate.syncing);
          } else {
            // Drain already queued raw finishes/revisions before the one pass read.
            // Those streams are asynchronous even though activity is synchronous.
            timer = Timer(Duration.zero, () {
              completionPending = false;
              if (!_wallet.isSyncPassActive) {
                controller.add(TransactionHistoryUpdate.reload);
              }
            });
          }
        });
        void invalidate() {
          if (active || completionPending) return;
          // Direct finishes can change joins without producing a revision.
          // Coalesce them with direct writes and background deliveries.
          timer?.cancel();
          timer = Timer(const Duration(seconds: 3), () {
            if (!_wallet.isSyncPassActive) {
              controller.add(TransactionHistoryUpdate.reload);
            }
          });
        }

        revisions = _wallet.watchRevisions().listen((_) => invalidate());
        finishes = _wallet.watchSyncFinished().listen((_) => invalidate());
      },
      onCancel: () async {
        timer?.cancel();
        await Future.wait([
          if (activity case final subscription?) subscription.cancel(),
          if (revisions case final subscription?) subscription.cancel(),
          if (finishes case final subscription?) subscription.cancel(),
        ]);
      },
    );
    return controller.stream;
  }
}
