import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/errors/buy_error.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/buy/domain/accelerate_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/cancel_abandoned_buy_payjoin_usecase.dart';
import 'package:bb_mobile/features/buy/domain/confirm_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/create_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/get_buy_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/buy/domain/label_completed_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/refresh_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/set_buy_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockGetReceiveAddressUsecase extends Mock
    implements GetReceiveAddressUsecase {}

class _MockGetExchangeUserSummaryUsecase extends Mock
    implements GetExchangeUserSummaryUsecase {}

class _MockConfirmBuyOrderUsecase extends Mock
    implements ConfirmBuyOrderUsecase {}

class _MockCreateBuyOrderUsecase extends Mock
    implements CreateBuyOrderUsecase {}

class _MockRefreshBuyOrderUsecase extends Mock
    implements RefreshBuyOrderUsecase {}

class _MockGetNetworkFeesUsecase extends Mock
    implements GetNetworkFeesUsecase {}

class _MockConvertSatsToCurrencyAmountUsecase extends Mock
    implements ConvertSatsToCurrencyAmountUsecase {}

class _MockAccelerateBuyOrderUsecase extends Mock
    implements AccelerateBuyOrderUsecase {}

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockCancelAbandonedBuyPayjoinUsecase extends Mock
    implements CancelAbandonedBuyPayjoinUsecase {}

class _MockGetBuyPayjoinEnabledUsecase extends Mock
    implements GetBuyPayjoinEnabledUsecase {}

class _MockSetBuyPayjoinEnabledUsecase extends Mock
    implements SetBuyPayjoinEnabledUsecase {}

class _SeedableBuyBloc extends BuyBloc {
  _SeedableBuyBloc({
    required super.getWalletsUsecase,
    required super.getReceiveAddressUsecase,
    required super.getExchangeUserSummaryUsecase,
    required super.confirmBuyOrderUsecase,
    required super.createBuyOrderUsecase,
    required super.refreshBuyOrderUsecase,
    required super.getNetworkFeesUsecase,
    required super.convertSatsToCurrencyAmountUsecase,
    required super.accelerateBuyOrderUsecase,
    required super.getSettingsUsecase,
    required super.cancelAbandonedBuyPayjoinUsecase,
    required super.getBuyPayjoinEnabledUsecase,
    required super.setBuyPayjoinEnabledUsecase,
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
      ).thenAnswer((_) async {});
      final bloc = _SeedableBuyBloc(
        getWalletsUsecase: _MockGetWalletsUsecase(),
        getReceiveAddressUsecase: _MockGetReceiveAddressUsecase(),
        getExchangeUserSummaryUsecase: _MockGetExchangeUserSummaryUsecase(),
        confirmBuyOrderUsecase: _MockConfirmBuyOrderUsecase(),
        createBuyOrderUsecase: _MockCreateBuyOrderUsecase(),
        refreshBuyOrderUsecase: _MockRefreshBuyOrderUsecase(),
        getNetworkFeesUsecase: _MockGetNetworkFeesUsecase(),
        convertSatsToCurrencyAmountUsecase:
            _MockConvertSatsToCurrencyAmountUsecase(),
        accelerateBuyOrderUsecase: _MockAccelerateBuyOrderUsecase(),
        getSettingsUsecase: _MockGetSettingsUsecase(),
        cancelAbandonedBuyPayjoinUsecase: cancelAbandonedPayjoin,
        getBuyPayjoinEnabledUsecase: _MockGetBuyPayjoinEnabledUsecase(),
        setBuyPayjoinEnabledUsecase: _MockSetBuyPayjoinEnabledUsecase(),
        labelCompletedBuyOrderUsecase: _MockLabelCompletedBuyOrderUsecase(),
      );
      bloc.seed(BuyState(buyOrder: order));

      await bloc.close();

      verify(() => cancelAbandonedPayjoin.execute(order)).called(1);
    },
  );

  test('the per-order payjoin toggle writes through to the global trading '
      'setting', () async {
    final setPayjoinEnabled = _MockSetBuyPayjoinEnabledUsecase();
    when(() => setPayjoinEnabled.execute(any())).thenAnswer((_) async => null);
    final bloc = _SeedableBuyBloc(
      getWalletsUsecase: _MockGetWalletsUsecase(),
      getReceiveAddressUsecase: _MockGetReceiveAddressUsecase(),
      getExchangeUserSummaryUsecase: _MockGetExchangeUserSummaryUsecase(),
      confirmBuyOrderUsecase: _MockConfirmBuyOrderUsecase(),
      createBuyOrderUsecase: _MockCreateBuyOrderUsecase(),
      refreshBuyOrderUsecase: _MockRefreshBuyOrderUsecase(),
      getNetworkFeesUsecase: _MockGetNetworkFeesUsecase(),
      convertSatsToCurrencyAmountUsecase:
          _MockConvertSatsToCurrencyAmountUsecase(),
      accelerateBuyOrderUsecase: _MockAccelerateBuyOrderUsecase(),
      getSettingsUsecase: _MockGetSettingsUsecase(),
      cancelAbandonedBuyPayjoinUsecase: _MockCancelAbandonedBuyPayjoinUsecase(),
      getBuyPayjoinEnabledUsecase: _MockGetBuyPayjoinEnabledUsecase(),
      setBuyPayjoinEnabledUsecase: setPayjoinEnabled,
      labelCompletedBuyOrderUsecase: _MockLabelCompletedBuyOrderUsecase(),
    );
    addTearDown(bloc.close);

    bloc.add(const BuyEvent.payjoinToggled(false));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.isPayjoinEnabled, isFalse);
    verify(() => setPayjoinEnabled.execute(false)).called(1);

    bloc.add(const BuyEvent.payjoinToggled(true));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.isPayjoinEnabled, isTrue);
    verify(() => setPayjoinEnabled.execute(true)).called(1);
  });

  test('a pending payjoin update blocks order creation', () async {
    final completer = Completer<BuyError?>();
    final setPayjoinEnabled = _MockSetBuyPayjoinEnabledUsecase();
    final createOrder = _MockCreateBuyOrderUsecase();
    when(
      () => setPayjoinEnabled.execute(true),
    ).thenAnswer((_) => completer.future);
    final bloc = _SeedableBuyBloc(
      getWalletsUsecase: _MockGetWalletsUsecase(),
      getReceiveAddressUsecase: _MockGetReceiveAddressUsecase(),
      getExchangeUserSummaryUsecase: _MockGetExchangeUserSummaryUsecase(),
      confirmBuyOrderUsecase: _MockConfirmBuyOrderUsecase(),
      createBuyOrderUsecase: createOrder,
      refreshBuyOrderUsecase: _MockRefreshBuyOrderUsecase(),
      getNetworkFeesUsecase: _MockGetNetworkFeesUsecase(),
      convertSatsToCurrencyAmountUsecase:
          _MockConvertSatsToCurrencyAmountUsecase(),
      accelerateBuyOrderUsecase: _MockAccelerateBuyOrderUsecase(),
      getSettingsUsecase: _MockGetSettingsUsecase(),
      cancelAbandonedBuyPayjoinUsecase: _MockCancelAbandonedBuyPayjoinUsecase(),
      getBuyPayjoinEnabledUsecase: _MockGetBuyPayjoinEnabledUsecase(),
      setBuyPayjoinEnabledUsecase: setPayjoinEnabled,
      labelCompletedBuyOrderUsecase: _MockLabelCompletedBuyOrderUsecase(),
    );
    addTearDown(bloc.close);

    bloc.add(const BuyEvent.payjoinToggled(true));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.isUpdatingPayjoin, isTrue);

    bloc.add(const BuyEvent.createOrder());
    await Future<void>.delayed(Duration.zero);
    verifyZeroInteractions(createOrder);

    completer.complete();
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.isUpdatingPayjoin, isFalse);
  });

  test(
    'a failed payjoin update restores the prior value and surfaces error',
    () async {
      final setPayjoinEnabled = _MockSetBuyPayjoinEnabledUsecase();
      when(
        () => setPayjoinEnabled.execute(false),
      ).thenAnswer((_) async => const BuyError.payjoinSettingUpdateFailed());
      final bloc = _SeedableBuyBloc(
        getWalletsUsecase: _MockGetWalletsUsecase(),
        getReceiveAddressUsecase: _MockGetReceiveAddressUsecase(),
        getExchangeUserSummaryUsecase: _MockGetExchangeUserSummaryUsecase(),
        confirmBuyOrderUsecase: _MockConfirmBuyOrderUsecase(),
        createBuyOrderUsecase: _MockCreateBuyOrderUsecase(),
        refreshBuyOrderUsecase: _MockRefreshBuyOrderUsecase(),
        getNetworkFeesUsecase: _MockGetNetworkFeesUsecase(),
        convertSatsToCurrencyAmountUsecase:
            _MockConvertSatsToCurrencyAmountUsecase(),
        accelerateBuyOrderUsecase: _MockAccelerateBuyOrderUsecase(),
        getSettingsUsecase: _MockGetSettingsUsecase(),
        cancelAbandonedBuyPayjoinUsecase:
            _MockCancelAbandonedBuyPayjoinUsecase(),
        getBuyPayjoinEnabledUsecase: _MockGetBuyPayjoinEnabledUsecase(),
        setBuyPayjoinEnabledUsecase: setPayjoinEnabled,
        labelCompletedBuyOrderUsecase: _MockLabelCompletedBuyOrderUsecase(),
      );
      addTearDown(bloc.close);

      bloc.add(const BuyEvent.payjoinToggled(false));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.isPayjoinEnabled, isTrue);
      expect(bloc.state.isUpdatingPayjoin, isFalse);
      expect(
        bloc.state.createOrderBuyError,
        const BuyError.payjoinSettingUpdateFailed(),
      );
    },
  );
}
