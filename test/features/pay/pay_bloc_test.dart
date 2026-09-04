import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/pay/domain/broadcast_pay_payin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/calculate_pay_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/pay/domain/get_pay_order_usecase.dart';
import 'package:bb_mobile/features/pay/domain/get_pay_payin_address_usecase.dart';
import 'package:bb_mobile/features/pay/domain/load_pay_network_fees_usecase.dart';
import 'package:bb_mobile/features/pay/domain/load_pay_user_summary_usecase.dart';
import 'package:bb_mobile/features/pay/domain/place_pay_order_usecase.dart';
import 'package:bb_mobile/features/pay/domain/estimate_pay_payin_fees_usecase.dart';
import 'package:bb_mobile/features/pay/domain/load_pay_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bb_mobile/features/pay/domain/prepare_pay_bitcoin_payin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/prepare_pay_liquid_payin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/sign_pay_payin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/get_payjoin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/refresh_pay_order_usecase.dart';
import 'package:bb_mobile/features/pay/domain/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/watch_payjoin_usecase.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_presets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
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

class _MockCalculatePayAbsoluteFeesUsecase extends Mock
    implements CalculatePayAbsoluteFeesUsecase {}

class _MockGetPayPayinAddressUsecase extends Mock
    implements GetPayPayinAddressUsecase {}

class _MockGetPayOrderUsecase extends Mock implements GetPayOrderUsecase {}

class _MockSendWithPayjoinUsecase extends Mock
    implements SendWithPayjoinUsecase {}

class _MockWatchPayjoinUsecase extends Mock implements WatchPayjoinUsecase {}

class _MockGetPayjoinUsecase extends Mock implements GetPayjoinUsecase {}

class _MockPreviewBitcoinFeeUsecase extends Mock
    implements PreviewBitcoinFeeUsecase {}

class _MockPreviewBitcoinFeePresetsUsecase extends Mock
    implements PreviewBitcoinFeePresetsUsecase {}

class _MockWallet extends Mock implements Wallet {}

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
    required super.calculatePayAbsoluteFeesUsecase,
    required super.getPayPayinAddressUsecase,
    required super.sendWithPayjoinUsecase,
    required super.watchPayjoinUsecase,
    required super.getPayjoinUsecase,
    required super.previewBitcoinFeeUsecase,
    required super.previewBitcoinFeePresetsUsecase,
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
        confirmationDeadline: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        liquidAddress: 'lq1address',
        beneficiaryName: beneficiaryName,
        isTestnet: false,
      )
      as FiatPaymentOrder;
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

void main() {
  late _MockPreparePayLiquidPayinUsecase prepareLiquidPayin;
  late _MockSignPayPayinUsecase signPayin;
  late _MockBroadcastPayPayinUsecase broadcastPayin;
  late _MockGetPayOrderUsecase getOrder;
  late _MockWallet wallet;

  _SeedablePayBloc buildBloc() => _SeedablePayBloc(
    loadPayUserSummaryUsecase: _MockLoadPayUserSummaryUsecase(),
    placePayOrderUsecase: _MockPlacePayOrderUsecase(),
    refreshPayOrderUsecase: _MockRefreshPayOrderUsecase(),
    estimatePayPayinFeesUsecase: _MockEstimatePayPayinFeesUsecase(),
    preparePayBitcoinPayinUsecase: _MockPreparePayBitcoinPayinUsecase(),
    preparePayLiquidPayinUsecase: prepareLiquidPayin,
    signPayPayinUsecase: signPayin,
    broadcastPayPayinUsecase: broadcastPayin,
    loadPayWalletUtxosUsecase: _MockLoadPayWalletUtxosUsecase(),
    sendWithPayjoinUsecase: _MockSendWithPayjoinUsecase(),
    watchPayjoinUsecase: _MockWatchPayjoinUsecase(),
    getPayjoinUsecase: _MockGetPayjoinUsecase(),
    loadPayNetworkFeesUsecase: _MockLoadPayNetworkFeesUsecase(),
    calculatePayAbsoluteFeesUsecase: _MockCalculatePayAbsoluteFeesUsecase(),
    getPayPayinAddressUsecase: _MockGetPayPayinAddressUsecase(),
    getPayOrderUsecase: getOrder,
    previewBitcoinFeeUsecase: _MockPreviewBitcoinFeeUsecase(),
    previewBitcoinFeePresetsUsecase: _MockPreviewBitcoinFeePresetsUsecase(),
  );

  setUpAll(() {
    registerFallbackValue(const RelativeFee(25));
  });

  setUp(() {
    prepareLiquidPayin = _MockPreparePayLiquidPayinUsecase();
    signPayin = _MockSignPayPayinUsecase();
    broadcastPayin = _MockBroadcastPayPayinUsecase();
    getOrder = _MockGetPayOrderUsecase();
    wallet = _MockWallet();

    when(() => wallet.id).thenReturn('wallet-1');
    when(() => wallet.isLiquid).thenReturn(true);
    when(
      () => prepareLiquidPayin.execute(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        feeRate: any(named: 'feeRate'),
      ),
    ).thenAnswer((_) async => const Ok<String, PayFailure>('pset'));
    when(
      () => signPayin.liquid(
        pset: any(named: 'pset'),
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) async => const Ok<String, PayFailure>('signed-pset'));
    when(
      () => broadcastPayin.liquid(any()),
    ).thenAnswer((_) async => const Ok<String, PayFailure>('txid'));
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
}
