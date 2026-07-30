import 'dart:async';

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/fees/domain/fee_preview_cache.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/sell/domain/create_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/refresh_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_presets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Ok, Sats;

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

class _MockSendWithPayjoin extends Mock implements SendWithPayjoinUsecase {}

class _MockPreviewBitcoinFee extends Mock implements PreviewBitcoinFeeUsecase {}

class _MockPreviewBitcoinFeePresets extends Mock
    implements PreviewBitcoinFeePresetsUsecase {}

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
    required super.sendWithPayjoinUsecase,
    required super.getNetworkFeesUsecase,
    required super.calculateLiquidAbsoluteFeesUsecase,
    required super.calculateBitcoinAbsoluteFeesUsecase,
    required super.convertSatsToCurrencyAmountUsecase,
    required super.getAddressAtIndexUsecase,
    required super.getWalletUtxosUsecase,
    required super.getOrderUsecase,
    required super.labelsFacade,
    required super.previewBitcoinFeeUsecase,
    required super.previewBitcoinFeePresetsUsecase,
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

  // Tiers far enough apart that the rate handed to the PSBT build identifies
  // which one the bloc picked.
  final feeOptions = FeeOptions(
    fastest: NetworkFee.relativeFromSatPerVbyte(10),
    economic: NetworkFee.relativeFromSatPerVbyte(5),
    slow: NetworkFee.relativeFromSatPerVbyte(1),
    minRelay: NetworkFee.relativeFromSatPerVbyte(0.1),
  );

  late _MockPrepareBitcoinSend prepareBitcoinSend;
  late _MockSignBitcoinTx signBitcoinTx;
  late _MockBroadcastBitcoin broadcastBitcoin;
  late _MockCalculateBitcoinFees calculateBitcoinFees;
  late _MockGetNetworkFees getNetworkFees;
  late _MockGetOrder getOrder;
  late _MockSendWithPayjoin sendWithPayjoin;
  late _MockRefreshSellOrder refreshSellOrder;
  late _MockLabelsFacade labelsFacade;
  late _MockPreviewBitcoinFee previewBitcoinFee;
  late _MockPreviewBitcoinFeePresets previewBitcoinFeePresets;
  late _MockSellOrder sellOrder;
  late _MockWallet wallet;
  late _SeedableSellBloc bloc;

  /// Every `networkFee` the bloc handed to a PSBT build, in call order.
  List<NetworkFee> capturedBuildFees() => verify(
    () => prepareBitcoinSend.execute(
      walletId: any(named: 'walletId'),
      address: any(named: 'address'),
      amountSat: any(named: 'amountSat'),
      networkFee: captureAny(named: 'networkFee'),
      selectedInputs: any(named: 'selectedInputs'),
      replaceByFee: any(named: 'replaceByFee'),
    ),
  ).captured.cast<NetworkFee>();

  /// Asserts the bloc never asked for a PSBT build. Separate from
  /// [capturedBuildFees] because `verify` needs at least one matching call.
  void verifyNoBuilds() => verifyNever(
    () => prepareBitcoinSend.execute(
      walletId: any(named: 'walletId'),
      address: any(named: 'address'),
      amountSat: any(named: 'amountSat'),
      networkFee: any(named: 'networkFee'),
      selectedInputs: any(named: 'selectedInputs'),
      replaceByFee: any(named: 'replaceByFee'),
    ),
  );

  setUpAll(() {
    registerFallbackValue(_FakeNewLabel());
    registerFallbackValue(const NetworkFee.absolute(200));
    registerFallbackValue(<WalletUtxo>[]);
    registerFallbackValue(
      FeeOptions(
        fastest: NetworkFee.relativeFromSatPerVbyte(1),
        economic: NetworkFee.relativeFromSatPerVbyte(1),
        slow: NetworkFee.relativeFromSatPerVbyte(1),
        minRelay: NetworkFee.relativeFromSatPerVbyte(0.1),
      ),
    );
  });

  setUp(() {
    prepareBitcoinSend = _MockPrepareBitcoinSend();
    signBitcoinTx = _MockSignBitcoinTx();
    broadcastBitcoin = _MockBroadcastBitcoin();
    calculateBitcoinFees = _MockCalculateBitcoinFees();
    getNetworkFees = _MockGetNetworkFees();
    getOrder = _MockGetOrder();
    sendWithPayjoin = _MockSendWithPayjoin();
    refreshSellOrder = _MockRefreshSellOrder();
    labelsFacade = _MockLabelsFacade();
    previewBitcoinFee = _MockPreviewBitcoinFee();
    previewBitcoinFeePresets = _MockPreviewBitcoinFeePresets();
    sellOrder = _MockSellOrder();
    wallet = _MockWallet();

    when(() => wallet.id).thenReturn('wallet-1');
    when(() => wallet.isLiquid).thenReturn(false);
    when(() => wallet.network).thenReturn(Network.bitcoinMainnet);
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
    when(
      () => getNetworkFees.execute(isLiquid: any(named: 'isLiquid')),
    ).thenAnswer((_) async => feeOptions);

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
      sendWithPayjoinUsecase: sendWithPayjoin,
      getNetworkFeesUsecase: getNetworkFees,
      calculateLiquidAbsoluteFeesUsecase: _MockCalculateLiquidFees(),
      calculateBitcoinAbsoluteFeesUsecase: calculateBitcoinFees,
      convertSatsToCurrencyAmountUsecase: _MockConvertSatsToCurrency(),
      getAddressAtIndexUsecase: _MockGetAddressAtIndex(),
      getWalletUtxosUsecase: _MockGetWalletUtxos(),
      getOrderUsecase: getOrder,
      labelsFacade: labelsFacade,
      previewBitcoinFeeUsecase: previewBitcoinFee,
      previewBitcoinFeePresetsUsecase: previewBitcoinFeePresets,
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
        // Present as soon as the confirmation screen is reached: the wallet
        // selection fetches the tiers to price the first estimate.
        bitcoinFees: feeOptions,
        bitcoinTxSize: 110,
      ),
    );
  });

  tearDown(() => bloc.close());

  group('SellBloc — broadcast latch', () {
    test('Payjoin toggle is ignored while confirmation is in flight', () async {
      bloc.seed(
        (bloc.state as SellPaymentState).copyWith(isConfirmingPayment: true),
      );

      bloc.add(const SellEvent.payjoinToggled(false));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect((bloc.state as SellPaymentState).isPayjoinEnabled, isTrue);
    });

    test('absolute custom fees pass their actual rate to Payjoin', () async {
      const bip21 =
          'bitcoin:bc1q0000000000000000000000000000000000000'
          '?amount=0.001&pj=https://payjo.in/session';
      when(() => sellOrder.bip21URI).thenReturn(bip21);
      when(
        () => calculateBitcoinFees.execute(psbt: any(named: 'psbt')),
      ).thenAnswer((_) async => 1100);
      bloc.seed(
        (bloc.state as SellPaymentState).copyWith(
          selectedFeeOption: FeeSelection.custom,
          customFee: const NetworkFee.absolute(1100),
          absoluteFees: 1100,
        ),
      );
      when(
        () => sendWithPayjoin.execute(
          walletId: any(named: 'walletId'),
          isTestnet: any(named: 'isTestnet'),
          bip21: any(named: 'bip21'),
          unsignedOriginalPsbt: any(named: 'unsignedOriginalPsbt'),
          amountSat: any(named: 'amountSat'),
          networkFeesSatPerVb: any(named: 'networkFeesSatPerVb'),
          expireAfterSec: any(named: 'expireAfterSec'),
        ),
      ).thenAnswer(
        (_) async => PayjoinSenderSession(
          status: PayjoinStatus.requested,
          uri: bip21,
          network: BitcoinNetwork.mainnet,
          walletId: 'wallet-1',
          originalTransactionId: expectedTxid,
          amount: Sats.fromInt(100000),
          createdAt: DateTime(2026),
          expiresAt: DateTime(2026).add(const Duration(minutes: 5)),
        ),
      );

      bloc.add(const SellEvent.sendPaymentConfirmed());
      await bloc.stream.firstWhere(
        (state) => state is SellPaymentState && state.isPayinBroadcast,
      );

      verify(
        () => sendWithPayjoin.execute(
          walletId: 'wallet-1',
          isTestnet: false,
          bip21: bip21,
          unsignedOriginalPsbt: unsignedPsbt,
          amountSat: 100000,
          networkFeesSatPerVb: 10,
          expireAfterSec: any(named: 'expireAfterSec'),
        ),
      ).called(1);
    });

    test(
      'a Payjoin session locks Confirm and uses the selected fee rate',
      () async {
        const bip21 =
            'bitcoin:bc1q0000000000000000000000000000000000000'
            '?amount=0.001&pj=https://payjo.in/session';
        when(() => sellOrder.bip21URI).thenReturn(bip21);
        when(
          () => sendWithPayjoin.execute(
            walletId: any(named: 'walletId'),
            isTestnet: any(named: 'isTestnet'),
            bip21: any(named: 'bip21'),
            unsignedOriginalPsbt: any(named: 'unsignedOriginalPsbt'),
            amountSat: any(named: 'amountSat'),
            networkFeesSatPerVb: any(named: 'networkFeesSatPerVb'),
            expireAfterSec: any(named: 'expireAfterSec'),
          ),
        ).thenAnswer(
          (_) async => PayjoinSenderSession(
            status: PayjoinStatus.requested,
            uri: bip21,
            network: BitcoinNetwork.mainnet,
            walletId: 'wallet-1',
            originalTransactionId: expectedTxid,
            amount: Sats.fromInt(100000),
            createdAt: DateTime(2026),
            expiresAt: DateTime(2026).add(const Duration(minutes: 5)),
          ),
        );
        when(
          () => getOrder.execute(orderId: any(named: 'orderId')),
        ).thenThrow(GetOrderException('dns failure'));

        bloc.add(const SellEvent.sendPaymentConfirmed());
        await bloc.stream.firstWhere(
          (state) => state is SellPaymentState && state.isPayinBroadcast,
        );

        verify(
          () => sendWithPayjoin.execute(
            walletId: 'wallet-1',
            isTestnet: any(named: 'isTestnet'),
            bip21: bip21,
            unsignedOriginalPsbt: unsignedPsbt,
            amountSat: 100000,
            networkFeesSatPerVb: 10,
            expireAfterSec: any(named: 'expireAfterSec'),
          ),
        ).called(1);
        verifyNever(
          () => broadcastBitcoin.execute(any(), isPsbt: any(named: 'isPsbt')),
        );

        bloc.add(const SellEvent.sendPaymentConfirmed());
        await Future<void>.delayed(const Duration(milliseconds: 100));

        verifyNoMoreInteractions(sendWithPayjoin);
      },
    );

    test(
      'a second confirmation after the payin is broadcast does not broadcast '
      'again',
      () async {
        // The post-broadcast order fetch fails, which used to re-enable Confirm
        // with the transaction already on the wire (#2522).
        when(
          () => getOrder.execute(orderId: any(named: 'orderId')),
        ).thenThrow(GetOrderException('dns failure'));

        bloc.add(const SellEvent.sendPaymentConfirmed());
        await bloc.stream.firstWhere(
          (state) => state is SellPaymentState && state.isPayinBroadcast,
        );

        final latched = bloc.state as SellPaymentState;
        expect(latched.payinBroadcastTxid, expectedTxid);

        // Let the failing order fetch settle, then confirm again.
        await Future<void>.delayed(const Duration(seconds: 6));
        bloc.add(const SellEvent.sendPaymentConfirmed());
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

        bloc.add(const SellEvent.sendPaymentConfirmed());
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

      bloc.add(const SellEvent.sendPaymentConfirmed());
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
    // The refresh compares payin amounts to decide whether the cached fee
    // previews still describe this order.
    when(() => refreshedOrder.payinAmount).thenReturn(0.001);
    when(
      () => refreshSellOrder.execute(orderId: any(named: 'orderId')),
    ).thenAnswer((_) async => refreshedOrder);

    bloc.add(const SellEvent.sendPaymentConfirmed());
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

  group('SellBloc — fee selection (#2521)', () {
    /// Resolves once the fee recalculation triggered by a selection has landed.
    Future<SellPaymentState> awaitRecalculatedFee() async {
      final state = await bloc.stream.firstWhere(
        (state) => state is SellPaymentState && state.absoluteFees != null,
      );
      return state as SellPaymentState;
    }

    /// Parks a fee recalculation inside its network-fee fetch, then moves the
    /// flow to the success state underneath it. Returns the completer so the
    /// caller decides whether the parked fetch succeeds or fails.
    Future<Completer<FeeOptions>> recalculationParkedPastSuccess() async {
      final feeFetch = Completer<FeeOptions>();
      when(
        () => getNetworkFees.execute(isLiquid: any(named: 'isLiquid')),
      ).thenAnswer((_) => feeFetch.future);

      bloc.add(const SellEvent.feeOptionSelected(FeeSelection.economic));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Stands in for the payin being broadcast and the order catching up while
      // the recalculation is still waiting on mempool rates.
      bloc.seed(
        SellState.success(bitcoinUnit: BitcoinUnit.sats, sellOrder: sellOrder),
      );
      return feeFetch;
    }

    test('a recalculation landing after the success transition emits '
        'nothing', () async {
      final feeFetch = await recalculationParkedPastSuccess();

      feeFetch.complete(feeOptions);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Republishing the pre-broadcast payment state here would take the user
      // off the success screen, drop the latch and re-arm Confirm on a payin
      // already on the wire (#2522).
      expect(bloc.state, isA<SellSuccessState>());
    });

    test('a recalculation failing after the success transition emits '
        'nothing', () async {
      final feeFetch = await recalculationParkedPastSuccess();

      feeFetch.completeError(Exception('mempool unreachable'));
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Same for the failure path: an error emitted onto a resurrected payment
      // state is an invitation to pay twice.
      expect(bloc.state, isA<SellSuccessState>());
    });

    test(
      'the payin is built at the selected preset, not Fastest',
      () async {
        // Nothing must complete the order — the assertion is about the rate the
        // build was asked for.
        when(
          () => getOrder.execute(orderId: any(named: 'orderId')),
        ).thenThrow(GetOrderException('dns failure'));

        bloc.add(const SellEvent.feeOptionSelected(FeeSelection.economic));
        final recalculated = await awaitRecalculatedFee();
        expect(recalculated.selectedFeeOption, FeeSelection.economic);

        bloc.add(const SellEvent.sendPaymentConfirmed());
        await bloc.stream.firstWhere(
          (state) => state is SellPaymentState && state.isPayinBroadcast,
        );

        // Both the estimate rebuild and the broadcast build used Economic; the
        // hardcoded Fastest rate must appear nowhere.
        expect(capturedBuildFees(), everyElement(equals(feeOptions.economic)));
        await Future<void>.delayed(const Duration(seconds: 6));
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'a typed custom rate is committed on dismissal and paid',
      () async {
        when(
          () => getOrder.execute(orderId: any(named: 'orderId')),
        ).thenThrow(GetOrderException('dns failure'));
        final customFee = NetworkFee.relativeFromSatPerVbyte(3);

        // Typing arms the rate without rebuilding; dismissing the modal is what
        // applies it.
        bloc.add(SellEvent.customFeeArmed(customFee));
        await bloc.stream.firstWhere(
          (state) =>
              state is SellPaymentState &&
              state.selectedFeeOption == FeeSelection.custom,
        );
        // Arming only deselects the preset tiles; the rebuild waits for the
        // commit on dismissal.
        verifyNoBuilds();

        bloc.add(const SellEvent.customFeeFinalized());
        final committed = await awaitRecalculatedFee();
        expect(committed.selectedFeeOption, FeeSelection.custom);
        expect(committed.customFee, customFee);
        expect(committed.armPriorSelection, isNull);

        bloc.add(const SellEvent.sendPaymentConfirmed());
        await bloc.stream.firstWhere(
          (state) => state is SellPaymentState && state.isPayinBroadcast,
        );

        expect(capturedBuildFees(), everyElement(equals(customFee)));
        await Future<void>.delayed(const Duration(seconds: 6));
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'a custom rate below the relay floor rolls back on dismissal',
      () async {
        // 0.05 sat/vB is under the 0.1 sat/vB floor, so dismissing discards it
        // rather than staging a transaction the network would not relay.
        bloc.add(
          SellEvent.customFeeArmed(NetworkFee.relativeFromSatPerVbyte(0.05)),
        );
        await bloc.stream.firstWhere(
          (state) =>
              state is SellPaymentState &&
              state.selectedFeeOption == FeeSelection.custom,
        );

        bloc.add(const SellEvent.customFeeFinalized());
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final state = bloc.state as SellPaymentState;
        expect(state.selectedFeeOption, FeeSelection.fastest);
        expect(state.customFee, isNull);
        verifyNoBuilds();
      },
    );

    test(
      'fee selection is inert once the payin is broadcast',
      () async {
        when(
          () => getOrder.execute(orderId: any(named: 'orderId')),
        ).thenThrow(GetOrderException('dns failure'));

        bloc.add(const SellEvent.sendPaymentConfirmed());
        await bloc.stream.firstWhere(
          (state) => state is SellPaymentState && state.isPayinBroadcast,
        );

        // Changing the fee now would rebuild under a transaction already on the
        // wire (#2522), so every fee event is dropped.
        bloc.add(const SellEvent.feeOptionSelected(FeeSelection.slow));
        bloc.add(
          SellEvent.customFeeArmed(NetworkFee.relativeFromSatPerVbyte(9)),
        );
        bloc.add(const SellEvent.presetFeesPreviewRequested());
        await Future<void>.delayed(const Duration(milliseconds: 200));

        final state = bloc.state as SellPaymentState;
        expect(state.selectedFeeOption, FeeSelection.fastest);
        expect(state.customFee, isNull);
        expect(state.payinBroadcastTxid, expectedTxid);
        verifyNever(
          () => previewBitcoinFeePresets.execute(
            presets: any(named: 'presets'),
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
            amountSat: any(named: 'amountSat'),
            replaceByFee: any(named: 'replaceByFee'),
            selectedInputs: any(named: 'selectedInputs'),
            drain: any(named: 'drain'),
          ),
        );
        // Only the one build that produced the broadcast transaction.
        expect(capturedBuildFees(), hasLength(1));
        await Future<void>.delayed(const Duration(seconds: 6));
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    /// Prices the three preset tiles the way an opened modal does.
    void stubPresetPreviews() {
      when(
        () => previewBitcoinFeePresets.execute(
          presets: any(named: 'presets'),
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
          amountSat: any(named: 'amountSat'),
          replaceByFee: any(named: 'replaceByFee'),
          selectedInputs: any(named: 'selectedInputs'),
          drain: any(named: 'drain'),
        ),
      ).thenAnswer(
        (_) async => const {
          FeeSelection.fastest: BitcoinFeePreviewSlot(
            feeSat: 1100,
            unsignedPsbt: unsignedPsbt,
            txSize: 110,
          ),
          FeeSelection.economic: BitcoinFeePreviewSlot(
            feeSat: 550,
            unsignedPsbt: unsignedPsbt,
            txSize: 110,
          ),
          FeeSelection.slow: BitcoinFeePreviewSlot(
            feeSat: 110,
            unsignedPsbt: unsignedPsbt,
            txSize: 110,
          ),
        },
      );
    }

    /// Resolves once the preset previews have filled the cache.
    Future<SellPaymentState> awaitPricedPresets() async {
      final state = await bloc.stream.firstWhere(
        (state) =>
            state is SellPaymentState &&
            !state.feePreviewCache.presetsLoading &&
            state.feePreviewCache.fastest.feeSat != null,
      );
      return state as SellPaymentState;
    }

    test('typing a custom rate leaves the preset prices standing', () async {
      stubPresetPreviews();
      bloc.add(const SellEvent.presetFeesPreviewRequested());
      await awaitPricedPresets();

      bloc.add(SellEvent.customFeeArmed(NetworkFee.relativeFromSatPerVbyte(4)));
      await bloc.stream.firstWhere(
        (state) =>
            state is SellPaymentState &&
            state.selectedFeeOption == FeeSelection.custom,
      );

      final cache = (bloc.state as SellPaymentState).feePreviewCache;
      // Only the custom slot priced the rate that just changed; wiping the
      // presets too would blank their tiles until the modal is reopened.
      expect(cache.fastest.feeSat, 1100);
      expect(cache.economic.feeSat, 550);
      expect(cache.slow.feeSat, 110);
      expect(cache.custom.feeSat, isNull);
    });

    test('opening the modal prices each preset from a built PSBT', () async {
      stubPresetPreviews();

      bloc.add(const SellEvent.presetFeesPreviewRequested());
      final state = await awaitPricedPresets();

      expect(state.feePreviewCache.fastest.feeSat, 1100);
      expect(state.feePreviewCache.economic.feeSat, 550);
      expect(state.feePreviewCache.slow.feeSat, 110);
      // The previews price the real payin, not a stand-in address.
      verify(
        () => previewBitcoinFeePresets.execute(
          presets: feeOptions,
          walletId: 'wallet-1',
          address: 'bc1q0000000000000000000000000000000000000',
          amountSat: 100000,
          replaceByFee: any(named: 'replaceByFee'),
          selectedInputs: any(named: 'selectedInputs'),
          drain: false,
        ),
      ).called(1);
    });
  });
}
