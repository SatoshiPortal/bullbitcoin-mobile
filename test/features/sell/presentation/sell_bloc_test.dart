import 'dart:async';

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/sell/domain/create_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/refresh_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetUserSummary extends Mock
    implements GetExchangeUserSummaryUsecase {}

class _MockGetSettings extends Mock implements GetSettingsUsecase {}

class _MockCreateSellOrder extends Mock implements CreateSellOrderUsecase {}

class _MockRefreshSellOrder extends Mock implements RefreshSellOrderUsecase {}

class _MockPrepareBitcoinSend extends Mock
    implements PrepareBitcoinSendUsecase {}

class _MockPrepareLiquidSend extends Mock implements PrepareLiquidSendUsecase {}

class _MockSignBitcoinTx extends Mock implements SignBitcoinTxUsecase {}

class _MockSignLiquidTx extends Mock implements SignLiquidTxUsecase {}

class _MockBroadcastBitcoin extends Mock
    implements BroadcastBitcoinTransactionUsecase {}

class _MockBroadcastLiquid extends Mock
    implements BroadcastLiquidTransactionUsecase {}

class _MockGetNetworkFees extends Mock implements GetNetworkFeesUsecase {}

class _MockCalculateLiquidFees extends Mock
    implements CalculateLiquidAbsoluteFeesUsecase {}

class _MockCalculateBitcoinFees extends Mock
    implements CalculateBitcoinAbsoluteFeesUsecase {}

class _MockConvertSatsToCurrency extends Mock
    implements ConvertSatsToCurrencyAmountUsecase {}

class _MockGetAddressAtIndex extends Mock implements GetAddressAtIndexUsecase {}

class _MockGetWalletUtxos extends Mock implements GetWalletUtxosUsecase {}

class _MockGetOrder extends Mock implements GetOrderUsecase {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

class _MockWallet extends Mock implements Wallet {}

class _MockSellOrder extends Mock implements SellOrder {}

class _FakeNewLabel extends Fake implements NewLabel {}

class _FakeLabel extends Fake implements Label {}

/// The confirmation path only ever runs from a [SellPaymentState] that earlier
/// events built up. Seeding it directly keeps this test to the send path and
/// avoids the order polling timer that order creation starts.
class _SeedableSellBloc extends SellBloc {
  _SeedableSellBloc({
    required super.getExchangeUserSummaryUsecase,
    required super.getSettingsUsecase,
    required super.createSellOrderUsecase,
    required super.refreshSellOrderUsecase,
    required super.prepareBitcoinSendUsecase,
    required super.prepareLiquidSendUsecase,
    required super.signBitcoinTxUsecase,
    required super.signLiquidTxUsecase,
    required super.broadcastBitcoinTransactionUsecase,
    required super.broadcastLiquidTransactionUsecase,
    required super.getNetworkFeesUsecase,
    required super.calculateLiquidAbsoluteFeesUsecase,
    required super.calculateBitcoinAbsoluteFeesUsecase,
    required super.convertSatsToCurrencyAmountUsecase,
    required super.getAddressAtIndexUsecase,
    required super.getWalletUtxosUsecase,
    required super.getOrderUsecase,
    required super.labelsFacade,
  });

  void seed(SellState state) => emit(state);
}

void main() {
  // Unsigned single-input single-output PSBT with a witness UTXO, enough for
  // BitcoinTx.fromPsbt to extract a txid.
  const unsignedPsbt =
      'cHNidP8BAFICAAAAARERERERERERERERERERERERERERERERERERERERERERAAAAAAD9////'
      'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
      'MzMzMzMzMzMzMzMzMzMzMzMAAA==';
  const expectedTxid =
      '813d01e5c0ea01904322222851b2e702d37651be2644f4757cc4421f39261b55';
  const userSummary = UserSummary(
    userNumber: 1,
    groups: ['KYC_IDENTITY_VERIFIED'],
    profile: UserProfile(firstName: 'Sat', lastName: 'Oshi'),
    email: 'sat@example.com',
    balances: [],
    dca: UserDca(isActive: false),
    autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
  );

  late _MockPrepareBitcoinSend prepareBitcoinSend;
  late _MockSignBitcoinTx signBitcoinTx;
  late _MockBroadcastBitcoin broadcastBitcoin;
  late _MockCalculateBitcoinFees calculateBitcoinFees;
  late _MockGetOrder getOrder;
  late _MockRefreshSellOrder refreshSellOrder;
  late _MockLabelsFacade labelsFacade;
  late _MockSellOrder sellOrder;
  late _MockWallet wallet;
  late _SeedableSellBloc bloc;

  setUpAll(() {
    registerFallbackValue(_FakeNewLabel());
    registerFallbackValue(const NetworkFee.absolute(200));
  });

  setUp(() {
    prepareBitcoinSend = _MockPrepareBitcoinSend();
    signBitcoinTx = _MockSignBitcoinTx();
    broadcastBitcoin = _MockBroadcastBitcoin();
    calculateBitcoinFees = _MockCalculateBitcoinFees();
    getOrder = _MockGetOrder();
    refreshSellOrder = _MockRefreshSellOrder();
    labelsFacade = _MockLabelsFacade();
    sellOrder = _MockSellOrder();
    wallet = _MockWallet();

    when(() => wallet.id).thenReturn('wallet-1');
    when(() => wallet.isLiquid).thenReturn(false);
    when(() => sellOrder.orderId).thenReturn('order-1');
    when(() => sellOrder.payinAmount).thenReturn(0.001);
    when(
      () => sellOrder.bitcoinAddress,
    ).thenReturn('bc1q0000000000000000000000000000000000000');
    when(
      () => sellOrder.confirmationDeadline,
    ).thenReturn(DateTime.now().add(const Duration(minutes: 5)));

    when(
      () => prepareBitcoinSend.execute(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        networkFee: any(named: 'networkFee'),
        selectedInputs: any(named: 'selectedInputs'),
        replaceByFee: any(named: 'replaceByFee'),
      ),
    ).thenAnswer(
      (_) async => (unsignedPsbt: unsignedPsbt, txSize: 110, isToSelf: false),
    );
    when(
      () => calculateBitcoinFees.execute(psbt: any(named: 'psbt')),
    ).thenAnswer((_) async => 200);
    when(
      () => signBitcoinTx.execute(
        psbt: any(named: 'psbt'),
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) async => (signedPsbt: unsignedPsbt, txSize: 110));
    when(
      () => broadcastBitcoin.execute(any(), isPsbt: any(named: 'isPsbt')),
    ).thenAnswer((_) async => expectedTxid);
    when(
      () => labelsFacade.store(any()),
    ).thenAnswer((_) async => Ok<Label, LabelFailure>(_FakeLabel()));

    bloc = _SeedableSellBloc(
      getExchangeUserSummaryUsecase: _MockGetUserSummary(),
      getSettingsUsecase: _MockGetSettings(),
      createSellOrderUsecase: _MockCreateSellOrder(),
      refreshSellOrderUsecase: refreshSellOrder,
      prepareBitcoinSendUsecase: prepareBitcoinSend,
      prepareLiquidSendUsecase: _MockPrepareLiquidSend(),
      signBitcoinTxUsecase: signBitcoinTx,
      signLiquidTxUsecase: _MockSignLiquidTx(),
      broadcastBitcoinTransactionUsecase: broadcastBitcoin,
      broadcastLiquidTransactionUsecase: _MockBroadcastLiquid(),
      getNetworkFeesUsecase: _MockGetNetworkFees(),
      calculateLiquidAbsoluteFeesUsecase: _MockCalculateLiquidFees(),
      calculateBitcoinAbsoluteFeesUsecase: calculateBitcoinFees,
      convertSatsToCurrencyAmountUsecase: _MockConvertSatsToCurrency(),
      getAddressAtIndexUsecase: _MockGetAddressAtIndex(),
      getWalletUtxosUsecase: _MockGetWalletUtxos(),
      getOrderUsecase: getOrder,
      labelsFacade: labelsFacade,
    );

    bloc.seed(
      SellState.payment(
        userSummary: userSummary,
        bitcoinUnit: BitcoinUnit.sats,
        orderAmount: BitcoinAmount(0.001),
        fiatCurrency: FiatCurrency.cad,
        selectedWallet: wallet,
        sellOrder: sellOrder,
        absoluteFees: 200,
      ),
    );
  });

  tearDown(() => bloc.close());

  group('SellBloc — broadcast latch', () {
    test(
      'a second confirmation after the payin is broadcast does not broadcast '
      'again',
      () async {
        // The post-broadcast order fetch fails, which used to re-enable Confirm
        // with the transaction already on the wire (#2522).
        when(
          () => getOrder.execute(orderId: any(named: 'orderId')),
        ).thenThrow(GetOrderException('dns failure'));

        bloc.add(
          const SellEvent.sendPaymentConfirmed(
            feeSelection: FeeSelection.fastest,
            customFee: null,
          ),
        );
        await bloc.stream.firstWhere(
          (state) => state is SellPaymentState && state.isPayinBroadcast,
        );

        final latched = bloc.state as SellPaymentState;
        expect(latched.payinBroadcastTxid, expectedTxid);

        // Let the failing order fetch settle, then confirm again.
        await Future<void>.delayed(const Duration(seconds: 6));
        bloc.add(
          const SellEvent.sendPaymentConfirmed(
            feeSelection: FeeSelection.fastest,
            customFee: null,
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 6));

        verify(
          () => broadcastBitcoin.execute(any(), isPsbt: any(named: 'isPsbt')),
        ).called(1);
        verify(
          () => prepareBitcoinSend.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
            amountSat: any(named: 'amountSat'),
            networkFee: any(named: 'networkFee'),
            selectedInputs: any(named: 'selectedInputs'),
            replaceByFee: any(named: 'replaceByFee'),
          ),
        ).called(1);

        final state = bloc.state as SellPaymentState;
        expect(state.payinBroadcastTxid, expectedTxid);
        // No retryable error, and Confirm stays disabled.
        expect(state.error, isNull);
        expect(state.isConfirmingPayment, isTrue);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'success state carries the order fetched after the broadcast',
      () async {
        final refreshedOrder = _MockSellOrder();
        when(() => refreshedOrder.orderId).thenReturn('order-1');
        when(
          () => getOrder.execute(orderId: any(named: 'orderId')),
        ).thenAnswer((_) async => refreshedOrder);

        bloc.add(
          const SellEvent.sendPaymentConfirmed(
            feeSelection: FeeSelection.fastest,
            customFee: null,
          ),
        );
        final successState = await bloc.stream.firstWhere(
          (state) => state is SellSuccessState,
        );

        expect(
          (successState as SellSuccessState).sellOrder,
          same(refreshedOrder),
        );
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test('an order poll spanning the broadcast keeps the latch', () async {
      // The poll runs for the life of the screen, so its fetch routinely spans
      // the broadcast. Holding the fetch open puts the latch inside that
      // window — where the poll used to emit its pre-await snapshot and re-arm
      // Confirm with the transaction already sent (#2522).
      final pollFetch = Completer<Order>();
      when(
        () => getOrder.execute(orderId: any(named: 'orderId')),
      ).thenAnswer((_) => pollFetch.future);

      final polledOrder = _MockSellOrder();
      when(() => polledOrder.orderId).thenReturn('order-1');
      when(
        () => polledOrder.payinStatus,
      ).thenReturn(OrderPayinStatus.awaitingPayment);

      bloc.add(const SellEvent.pollOrderStatus());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Stands in for the broadcast landing while the poll awaits its fetch.
      bloc.seed(
        (bloc.state as SellPaymentState).copyWith(
          isConfirmingPayment: true,
          payinBroadcastTxid: expectedTxid,
        ),
      );

      pollFetch.complete(polledOrder);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = bloc.state as SellPaymentState;
      expect(state.payinBroadcastTxid, expectedTxid);
      expect(state.isConfirmingPayment, isTrue);
      // The fresh order is still picked up, just merged into the live state.
      expect(state.sellOrder, same(polledOrder));
    });
  });

  test(
    'the price-lock refresh leaves a confirmation in flight alone',
    () async {
      when(
        () => getOrder.execute(orderId: any(named: 'orderId')),
      ).thenThrow(GetOrderException('dns failure'));

      bloc.add(
        const SellEvent.sendPaymentConfirmed(
          feeSelection: FeeSelection.fastest,
          customFee: null,
        ),
      );
      await bloc.stream.firstWhere(
        (state) => state is SellPaymentState && state.isConfirmingPayment,
      );

      bloc.add(const SellEvent.orderRefreshTimePassed());
      await Future<void>.delayed(const Duration(milliseconds: 100));

      verifyNever(
        () => refreshSellOrder.execute(orderId: any(named: 'orderId')),
      );
      expect((bloc.state as SellPaymentState).isConfirmingPayment, isTrue);

      // Let the confirmation settle so nothing emits after tearDown closes.
      await Future<void>.delayed(const Duration(seconds: 6));
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test('a failure past the price-lock deadline asks for a refresh', () async {
    // The countdown fires onTimeout once, and _onOrderRefreshTimePassed skipped
    // that one refresh because a confirmation was in flight. Nothing else would
    // ask again, so the bloc has to.
    when(
      () => sellOrder.confirmationDeadline,
    ).thenReturn(DateTime.now().subtract(const Duration(seconds: 1)));
    when(
      () => prepareBitcoinSend.execute(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        networkFee: any(named: 'networkFee'),
        selectedInputs: any(named: 'selectedInputs'),
        replaceByFee: any(named: 'replaceByFee'),
      ),
    ).thenThrow(PrepareBitcoinSendException('cannot build'));

    final refreshedOrder = _MockSellOrder();
    when(() => refreshedOrder.orderId).thenReturn('order-1');
    when(
      () => refreshSellOrder.execute(orderId: any(named: 'orderId')),
    ).thenAnswer((_) async => refreshedOrder);

    bloc.add(
      const SellEvent.sendPaymentConfirmed(
        feeSelection: FeeSelection.fastest,
        customFee: null,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    verify(() => refreshSellOrder.execute(orderId: 'order-1')).called(1);
    verifyNever(
      () => broadcastBitcoin.execute(any(), isPsbt: any(named: 'isPsbt')),
    );

    final state = bloc.state as SellPaymentState;
    expect(state.sellOrder, same(refreshedOrder));
    expect(state.isConfirmingPayment, isFalse);
    expect(state.payinBroadcastTxid, isNull);
    // The refresh must not erase why the send failed.
    expect(state.error, isNotNull);
  });
}
