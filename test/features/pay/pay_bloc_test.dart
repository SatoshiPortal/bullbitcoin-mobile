import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/pay/domain/create_pay_order_usecase.dart';
import 'package:bb_mobile/features/pay/domain/refresh_pay_order_usecase.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetExchangeUserSummaryUsecase extends Mock
    implements GetExchangeUserSummaryUsecase {}

class _MockPlacePayOrderUsecase extends Mock implements PlacePayOrderUsecase {}

class _MockRefreshPayOrderUsecase extends Mock
    implements RefreshPayOrderUsecase {}

class _MockPrepareBitcoinSendUsecase extends Mock
    implements PrepareBitcoinSendUsecase {}

class _MockPrepareLiquidSendUsecase extends Mock
    implements PrepareLiquidSendUsecase {}

class _MockSignBitcoinTxUsecase extends Mock implements SignBitcoinTxUsecase {}

class _MockSignLiquidTxUsecase extends Mock implements SignLiquidTxUsecase {}

class _MockBroadcastBitcoinTransactionUsecase extends Mock
    implements BroadcastBitcoinTransactionUsecase {}

class _MockBroadcastLiquidTransactionUsecase extends Mock
    implements BroadcastLiquidTransactionUsecase {}

class _MockGetNetworkFeesUsecase extends Mock
    implements GetNetworkFeesUsecase {}

class _MockCalculateLiquidAbsoluteFeesUsecase extends Mock
    implements CalculateLiquidAbsoluteFeesUsecase {}

class _MockCalculateBitcoinAbsoluteFeesUsecase extends Mock
    implements CalculateBitcoinAbsoluteFeesUsecase {}

class _MockConvertSatsToCurrencyAmountUsecase extends Mock
    implements ConvertSatsToCurrencyAmountUsecase {}

class _MockGetAddressAtIndexUsecase extends Mock
    implements GetAddressAtIndexUsecase {}

class _MockGetWalletUtxosUsecase extends Mock
    implements GetWalletUtxosUsecase {}

class _MockGetOrderUsecase extends Mock implements GetOrderUsecase {}

class _MockWallet extends Mock implements Wallet {}

/// Exposes [emit] so a test can put the bloc on the state under test instead of
/// driving the whole pay flow to get there.
class _SeedablePayBloc extends PayBloc {
  _SeedablePayBloc({
    required super.getExchangeUserSummaryUsecase,
    required super.placePayOrderUsecase,
    required super.refreshPayOrderUsecase,
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
  late _MockPrepareLiquidSendUsecase prepareLiquidSend;
  late _MockSignLiquidTxUsecase signLiquidTx;
  late _MockBroadcastLiquidTransactionUsecase broadcastLiquid;
  late _MockGetOrderUsecase getOrder;
  late _MockWallet wallet;

  _SeedablePayBloc buildBloc() => _SeedablePayBloc(
    getExchangeUserSummaryUsecase: _MockGetExchangeUserSummaryUsecase(),
    placePayOrderUsecase: _MockPlacePayOrderUsecase(),
    refreshPayOrderUsecase: _MockRefreshPayOrderUsecase(),
    prepareBitcoinSendUsecase: _MockPrepareBitcoinSendUsecase(),
    prepareLiquidSendUsecase: prepareLiquidSend,
    signBitcoinTxUsecase: _MockSignBitcoinTxUsecase(),
    signLiquidTxUsecase: signLiquidTx,
    broadcastBitcoinTransactionUsecase:
        _MockBroadcastBitcoinTransactionUsecase(),
    broadcastLiquidTransactionUsecase: broadcastLiquid,
    getNetworkFeesUsecase: _MockGetNetworkFeesUsecase(),
    calculateLiquidAbsoluteFeesUsecase:
        _MockCalculateLiquidAbsoluteFeesUsecase(),
    calculateBitcoinAbsoluteFeesUsecase:
        _MockCalculateBitcoinAbsoluteFeesUsecase(),
    convertSatsToCurrencyAmountUsecase:
        _MockConvertSatsToCurrencyAmountUsecase(),
    getAddressAtIndexUsecase: _MockGetAddressAtIndexUsecase(),
    getWalletUtxosUsecase: _MockGetWalletUtxosUsecase(),
    getOrderUsecase: getOrder,
  );

  setUpAll(() {
    registerFallbackValue(const RelativeFee(25));
  });

  setUp(() {
    prepareLiquidSend = _MockPrepareLiquidSendUsecase();
    signLiquidTx = _MockSignLiquidTxUsecase();
    broadcastLiquid = _MockBroadcastLiquidTransactionUsecase();
    getOrder = _MockGetOrderUsecase();
    wallet = _MockWallet();

    when(() => wallet.id).thenReturn('wallet-1');
    when(() => wallet.isLiquid).thenReturn(true);
    when(
      () => prepareLiquidSend.execute(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        feeRate: any(named: 'feeRate'),
      ),
    ).thenAnswer((_) async => 'pset');
    when(
      () => signLiquidTx.execute(
        pset: any(named: 'pset'),
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) async => 'signed-pset');
    when(() => broadcastLiquid.execute(any())).thenAnswer((_) async => 'txid');
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
    when(
      () => getOrder.execute(orderId: any(named: 'orderId')),
    ).thenAnswer((_) async => postBroadcastOrder);

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
    bloc.add(
      const PayEvent.sendPaymentConfirmed(feeSelection: FeeSelection.economic),
    );

    final state = await successState as PaySuccessState;
    expect(state.payOrder.payinStatus, OrderPayinStatus.awaitingConfirmation);
    expect(state.payOrder, same(postBroadcastOrder));
  });
}
