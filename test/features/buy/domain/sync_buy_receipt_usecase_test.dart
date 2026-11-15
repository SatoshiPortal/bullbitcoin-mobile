import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/buy/domain/sync_buy_receipt_usecase.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Order extends Mock implements BuyOrder {}

BuyOrder order(String id, OrderPayoutStatus status) {
  final value = _Order();
  when(() => value.orderId).thenReturn(id);
  when(() => value.payoutStatus).thenReturn(status);
  return value;
}

void main() {
  for (final status in OrderPayoutStatus.values) {
    test('payout $status requests only completed destination once', () async {
      final requested = <String>[];
      final sync = Completer<void>();
      final usecase = SyncBuyReceiptUsecase(
        WalletFacade(
          const Stream.empty(),
          pollWallet: (id, {required isActive}) {
            expect(isActive(), isTrue);
            requested.add(id);
            return sync.future;
          },
        ),
      );
      usecase.execute(
        order: order('buy', OrderPayoutStatus.notStarted),
        destinationWalletId: 'destination',
      );
      expect(requested, isEmpty);
      usecase.execute(order: order('other', OrderPayoutStatus.completed));
      expect(requested, isEmpty);
      usecase.execute(order: order('buy', status));
      usecase.execute(order: order('buy', status));
      expect(
        requested,
        status == OrderPayoutStatus.completed ? ['destination'] : isEmpty,
      );
      sync.complete();
    });
  }

  test('immediate completion is quiet on sync failure; unknown destination is skipped', () async {
    var requests = 0;
    final usecase = SyncBuyReceiptUsecase(
      WalletFacade(
        const Stream.empty(),
        pollWallet: (id, {required isActive}) async {
          requests++;
          throw Exception('unavailable');
        },
      ),
    );
    final completed = order('buy', OrderPayoutStatus.completed);
    usecase.execute(order: completed);
    expect(requests, 0);
    usecase.execute(order: completed, destinationWalletId: 'destination');
    usecase.execute(order: completed);
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
  });
}
