import 'package:spend/spend.dart';
import 'package:spend/testing.dart';
import 'package:bull_exchange/src/pay/domain/retry_payjoin_proposal_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:fees/fees.dart';
import 'package:sync/sync.dart' show WalletKey;
import 'package:bull_exchange/src/pay/domain/broadcast_pay_payin_usecase.dart';
import 'package:bull_exchange/src/pay/domain/get_pay_order_usecase.dart';
import 'package:bull_exchange/src/pay/domain/get_pay_payin_address_usecase.dart';
import 'package:bull_exchange/src/pay/domain/load_pay_network_fees_usecase.dart';
import 'package:bull_exchange/src/pay/domain/load_pay_user_summary_usecase.dart';
import 'package:bull_exchange/src/pay/domain/place_pay_order_usecase.dart';
import 'package:bull_exchange/src/pay/domain/estimate_pay_payin_fees_usecase.dart';
import 'package:bull_exchange/src/pay/domain/load_pay_wallet_utxos_usecase.dart';
import 'package:bull_exchange/src/pay/domain/pay_failure.dart';
import 'package:bull_exchange/src/pay/domain/prepare_pay_bitcoin_payin_usecase.dart';
import 'package:bull_exchange/src/pay/domain/prepare_pay_liquid_payin_usecase.dart';
import 'package:bull_exchange/src/pay/domain/sign_pay_payin_usecase.dart';
import 'package:bull_exchange/src/pay/domain/broadcast_payjoin_original_usecase.dart';
import 'package:bull_exchange/src/pay/domain/get_adoptable_payjoin_sender_usecase.dart';
import 'package:bull_exchange/src/pay/domain/get_visible_payjoin_transaction_usecase.dart';
import 'package:bull_exchange/src/pay/domain/refresh_pay_order_usecase.dart';
import 'package:bull_exchange/src/pay/domain/send_with_payjoin_usecase.dart';
import 'package:bull_exchange/src/pay/domain/watch_payjoin_usecase.dart';
import 'package:bull_exchange/src/pay/presentation/pay_bloc.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoadPayUserSummaryUsecase extends Mock
    implements LoadPayUserSummaryUsecase {}

class _MockPlacePayOrderUsecase extends Mock implements PlacePayOrderUsecase {}

class _MockRefreshPayOrderUsecase extends Mock
    implements RefreshPayOrderUsecase {}

class _MockEstimatePayPayinFeesUsecase extends Mock
    implements EstimatePayPayinFeesUsecase {}

class _MockPreparePayBitcoinPayinUsecase extends Mock
    implements PreparePayBitcoinPayinUsecase {}

class _MockPreparePayLiquidPayinUsecase extends Mock
    implements PreparePayLiquidPayinUsecase {}

class _MockSignPayPayinUsecase extends Mock implements SignPayPayinUsecase {}

class _MockBroadcastPayPayinUsecase extends Mock
    implements BroadcastPayPayinUsecase {}

class _MockLoadPayWalletUtxosUsecase extends Mock
    implements LoadPayWalletUtxosUsecase {}

class _MockLoadPayNetworkFeesUsecase extends Mock
    implements LoadPayNetworkFeesUsecase {}

class _MockGetPayPayinAddressUsecase extends Mock
    implements GetPayPayinAddressUsecase {}

class _MockGetPayOrderUsecase extends Mock implements GetPayOrderUsecase {}

class _MockSendWithPayjoinUsecase extends Mock
    implements SendWithPayjoinUsecase {}

class _MockWatchPayjoinUsecase extends Mock implements WatchPayjoinUsecase {}

class _MockGetAdoptablePayjoinSenderUsecase extends Mock
    implements GetAdoptablePayjoinSenderUsecase {}

class _MockBroadcastPayjoinOriginalUsecase extends Mock
    implements BroadcastPayjoinOriginalUsecase {}

class _MockGetVisiblePayjoinTransactionUsecase extends Mock
    implements GetVisiblePayjoinTransactionUsecase {}

/// Exposes [emit] so a test can put the bloc on the state under test instead of
/// driving the whole pay flow to get there.
class _SeedablePayBloc extends PayBloc {
  _SeedablePayBloc({
    required super.loadPayUserSummaryUsecase,
    required super.placePayOrderUsecase,
    required super.refreshPayOrderUsecase,
    required super.getPayOrderUsecase,
    required super.estimatePayPayinFeesUsecase,
    required super.preparePayBitcoinPayinUsecase,
    required super.preparePayLiquidPayinUsecase,
    required super.signPayPayinUsecase,
    required super.broadcastPayPayinUsecase,
    required super.loadPayWalletUtxosUsecase,
    required super.loadPayNetworkFeesUsecase,

    required super.getPayPayinAddressUsecase,
    required super.sendWithPayjoinUsecase,
    required super.watchPayjoinUsecase,
    required super.getAdoptablePayjoinSenderUsecase,
    required super.broadcastPayjoinOriginalUsecase,
    required super.getVisiblePayjoinTransactionUsecase,
    required super.retryPayjoinProposalUsecase,
    required super.spend,
  });

  void seed(PayState state) => emit(state);
}

FiatPaymentOrder _order({
  required OrderPayinStatus payinStatus,
  String beneficiaryName = 'Alice',
}) {
  return Order.fiatPayment(
    orderId: 'order-1',
    orderType: OrderType.fiatPayment,
    message: OrderMessage(code: '', message: ''),
    orderNumber: 1,
    payinAmount: 0.001,
    payinCurrency: 'LBTC',
    payoutAmount: 125.0,
    payoutCurrency: 'CAD',
    payinMethod: OrderPaymentMethod.liquid,
    payoutMethod: OrderPaymentMethod.bankTransfer,
    orderStatus: OrderStatus.inProgress,
    payinStatus: payinStatus,
    payoutStatus: OrderPayoutStatus.notStarted,
    // Ahead of the clock: a payin is never sent on a lapsed quote.
    confirmationDeadline: DateTime.now().add(const Duration(minutes: 5)),
    createdAt: DateTime(2026, 1, 1),
    liquidAddress: 'lq1address',
    beneficiaryName: beneficiaryName,
    isTestnet: false,
  ) as FiatPaymentOrder;
}

const _userSummary = UserSummary(
  userNumber: 1,
  groups: ['KYC_IDENTITY_VERIFIED'],
  profile: UserProfile(firstName: 'Bob', lastName: 'Builder'),
  email: 'bob@example.com',
  balances: [],
  dca: UserDca(isActive: false),
  autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
);

const _recipient = RecipientViewModel(
  id: 'recipient-1',
  type: RecipientType.bankTransferCad,
);

class _MockRetryPayjoin extends Mock implements RetryPayjoinProposalUsecase {}

class _MockSpend extends Mock implements Spend {}

void main() {
  final spend = _MockSpend();
  late _MockPreparePayLiquidPayinUsecase prepareLiquidPayin;
  late _MockSignPayPayinUsecase signPayin;
  late _MockBroadcastPayPayinUsecase broadcastPayin;
  late _MockGetPayOrderUsecase getOrder;
  late _MockRefreshPayOrderUsecase refreshOrder;
  late ExchangePayinWallet wallet;

  _SeedablePayBloc buildBloc() => _SeedablePayBloc(
    loadPayUserSummaryUsecase: _MockLoadPayUserSummaryUsecase(),
    placePayOrderUsecase: _MockPlacePayOrderUsecase(),
    refreshPayOrderUsecase: refreshOrder,
    estimatePayPayinFeesUsecase: _MockEstimatePayPayinFeesUsecase(),
    preparePayBitcoinPayinUsecase: _MockPreparePayBitcoinPayinUsecase(),
    preparePayLiquidPayinUsecase: prepareLiquidPayin,
    signPayPayinUsecase: signPayin,
    broadcastPayPayinUsecase: broadcastPayin,
    loadPayWalletUtxosUsecase: _MockLoadPayWalletUtxosUsecase(),
    sendWithPayjoinUsecase: _MockSendWithPayjoinUsecase(),
    watchPayjoinUsecase: _MockWatchPayjoinUsecase(),
    getAdoptablePayjoinSenderUsecase: _MockGetAdoptablePayjoinSenderUsecase(),
    broadcastPayjoinOriginalUsecase: _MockBroadcastPayjoinOriginalUsecase(),
    getVisiblePayjoinTransactionUsecase:
        _MockGetVisiblePayjoinTransactionUsecase(),
    retryPayjoinProposalUsecase: _MockRetryPayjoin(),
    loadPayNetworkFeesUsecase: _MockLoadPayNetworkFeesUsecase(),

    getPayPayinAddressUsecase: _MockGetPayPayinAddressUsecase(),
    getPayOrderUsecase: getOrder,
    spend: spend,
  );

  setUpAll(() {
    registerFallbackValue(
      WalletKey(id: 'fallback', network: BitcoinNetwork.mainnet),
    );
    registerFallbackValue(
      SpendFixtures.preparedBitcoin(unsignedPsbt: '', fee: Sats.zero),
    );
    registerFallbackValue(
      SpendFixtures.preparedLiquid(
        unsignedPset: '',
        fee: Sats.zero,
        amountSent: Sats.zero,
      ),
    );
    registerFallbackValue(SpendFixtures.signedBitcoin(''));
    registerFallbackValue(SpendFixtures.signedLiquid(''));

    registerFallbackValue(const RelativeFee(25));
  });

  setUp(() {
    prepareLiquidPayin = _MockPreparePayLiquidPayinUsecase();
    signPayin = _MockSignPayPayinUsecase();
    broadcastPayin = _MockBroadcastPayPayinUsecase();
    getOrder = _MockGetPayOrderUsecase();
    refreshOrder = _MockRefreshPayOrderUsecase();
    // The bloc polls on a timer; leaving this unstubbed makes any test that
    // outlives one tick fail on an unrelated null.
    when(
      () => refreshOrder.execute(
        orderId: any(named: 'orderId'),
        expectedDepositAddress: any(named: 'expectedDepositAddress'),
        expectedLightningInvoice: any(named: 'expectedLightningInvoice'),
      ),
    ).thenAnswer(
      (_) async => Ok<FiatPaymentOrder, PayFailure>(
        _order(payinStatus: OrderPayinStatus.awaitingPayment),
      ),
    );
    wallet = ExchangePayinWallet(
      key: WalletKey(id: 'wallet-1', network: LiquidNetwork.mainnet),
      balanceSat: BigInt.from(1000000),
    );

    when(
      () => prepareLiquidPayin.execute(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        feeRate: any(named: 'feeRate'),
      ),
    ).thenAnswer(
      (_) async => Ok(
        SpendFixtures.preparedLiquid(
          unsignedPset: 'pset',
          fee: Sats.zero,
          amountSent: Sats.fromInt(1),
        ),
      ),
    );
    when(() => signPayin.liquid(any()))
        .thenAnswer((_) async => Ok(SpendFixtures.signedLiquid('signed-pset')));
    when(() => broadcastPayin.liquid(any()))
        .thenAnswer((_) async => const Ok<String, PayFailure>('txid'));
  });

  // The handler waits 5s after broadcasting to let the backend register the
  // 0-conf payin before fetching the order, so this test takes that long.
  test('success state carries the order fetched after the broadcast', () async {
    final preBroadcastOrder = _order(
      payinStatus: OrderPayinStatus.awaitingPayment,
    );
    final postBroadcastOrder = _order(
      payinStatus: OrderPayinStatus.awaitingConfirmation,
    );
    when(() => getOrder.execute(orderId: any(named: 'orderId'))).thenAnswer(
      (_) async => Ok<FiatPaymentOrder, PayFailure>(postBroadcastOrder),
    );

    final bloc = buildBloc();
    addTearDown(bloc.close);
    bloc.seed(
      PayPaymentState(
        selectedRecipient: _recipient,
        userSummary: _userSummary,
        amount: const FiatAmount(125.0),
        selectedWallet: wallet,
        payOrder: preBroadcastOrder,
      ),
    );

    final successState = bloc.stream.firstWhere(
      (state) => state is PaySuccessState,
    );
    bloc.add(const PayEvent.sendPaymentConfirmed());

    final state = await successState as PaySuccessState;
    expect(state.payOrder.payinStatus, OrderPayinStatus.awaitingConfirmation);
    expect(state.payOrder, same(postBroadcastOrder));
  });

  // Every collaborator returns a Result today, so this can only happen if one
  // starts throwing. Without the catch-all the spinner would just stop and
  // Confirm would look like a no-op — which on a payment screen invites a
  // second tap.
  test('a throwing collaborator surfaces a sanitized failure', () async {
    const secret = 'PrepareLiquidSendException: xprv9s21ZrQH143K3';
    when(
      () => prepareLiquidPayin.execute(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        feeRate: any(named: 'feeRate'),
      ),
    ).thenThrow(Exception(secret));

    final bloc = buildBloc();
    addTearDown(bloc.close);
    bloc.seed(
      PayPaymentState(
        selectedRecipient: _recipient,
        userSummary: _userSummary,
        amount: const FiatAmount(125.0),
        selectedWallet: wallet,
        payOrder: _order(payinStatus: OrderPayinStatus.awaitingPayment),
      ),
    );

    final errored = bloc.stream.firstWhere(
      (state) => state is PayPaymentState && state.error != null,
    );
    bloc.add(const PayEvent.sendPaymentConfirmed());

    final state = await errored as PayPaymentState;
    expect(state.error, isA<PayUnexpectedFailure>());
    expect(
      state.error!.logMessage,
      isNot(contains('xprv9s21ZrQH143K3')),
      reason: 'the raw reason belongs in the log, not on the failure',
    );
    expect(
      state.isConfirmingPayment,
      isFalse,
      reason: 'the spinner must not be left spinning',
    );
  });
}
