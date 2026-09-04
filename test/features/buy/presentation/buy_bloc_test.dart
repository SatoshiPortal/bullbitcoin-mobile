import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/buy/domain/accelerate_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bb_mobile/features/buy/domain/cancel_abandoned_buy_payjoin_usecase.dart';
import 'package:bb_mobile/features/buy/domain/confirm_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/create_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/get_buy_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/buy/domain/load_buy_context_usecase.dart';
import 'package:bb_mobile/features/buy/domain/label_completed_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/refresh_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockConfirmBuyOrderUsecase extends Mock
    implements ConfirmBuyOrderUsecase {}

class _MockCreateBuyOrderUsecase extends Mock
    implements CreateBuyOrderUsecase {}

class _MockRefreshBuyOrderUsecase extends Mock
    implements RefreshBuyOrderUsecase {}

class _MockAccelerateBuyOrderUsecase extends Mock
    implements AccelerateBuyOrderUsecase {}

class _MockCancelAbandonedBuyPayjoinUsecase extends Mock
    implements CancelAbandonedBuyPayjoinUsecase {}

class _MockGetBuyPayjoinEnabledUsecase extends Mock
    implements GetBuyPayjoinEnabledUsecase {}

class _MockLoadBuyContextUsecase extends Mock
    implements LoadBuyContextUsecase {}

class _SeedableBuyBloc extends BuyBloc {
  _SeedableBuyBloc({
    required super.loadBuyContextUsecase,
    required super.confirmBuyOrderUsecase,
    required super.createBuyOrderUsecase,
    required super.refreshBuyOrderUsecase,
    required super.accelerateBuyOrderUsecase,
    required super.cancelAbandonedBuyPayjoinUsecase,
    required super.getBuyPayjoinEnabledUsecase,
    required super.labelCompletedBuyOrderUsecase,
  });

  void seed(BuyState state) => emit(state);
}

class _MockBuyOrder extends Mock implements BuyOrder {}

class _MockLabelCompletedBuyOrderUsecase extends Mock
    implements LabelCompletedBuyOrderUsecase {}

void main() {
  test(
    'closing the Buy flow cleans up its current unconfirmed order',
    () async {
      final cancelAbandonedPayjoin = _MockCancelAbandonedBuyPayjoinUsecase();
      final order = _MockBuyOrder();
      when(
        () => cancelAbandonedPayjoin.execute(order),
      ).thenAnswer((_) async => const Ok<void, BuyFailure>(null));
      final bloc = _SeedableBuyBloc(
        loadBuyContextUsecase: _MockLoadBuyContextUsecase(),
        confirmBuyOrderUsecase: _MockConfirmBuyOrderUsecase(),
        createBuyOrderUsecase: _MockCreateBuyOrderUsecase(),
        refreshBuyOrderUsecase: _MockRefreshBuyOrderUsecase(),
        accelerateBuyOrderUsecase: _MockAccelerateBuyOrderUsecase(),
        cancelAbandonedBuyPayjoinUsecase: cancelAbandonedPayjoin,
        getBuyPayjoinEnabledUsecase: _MockGetBuyPayjoinEnabledUsecase(),
        labelCompletedBuyOrderUsecase: _MockLabelCompletedBuyOrderUsecase(),
      );
      bloc.seed(BuyState(buyOrder: order));

      await bloc.close();

      verify(() => cancelAbandonedPayjoin.execute(order)).called(1);
    },
  );
}
