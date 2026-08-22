import 'dart:async';

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/errors/sell_error.dart';
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
import 'package:bb_mobile/features/sell/domain/label_completed_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/create_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/get_payjoin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/get_payjoin_trading_enabled_usecase.dart';
import 'package:bb_mobile/features/sell/domain/refresh_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/set_payjoin_trading_enabled_usecase.dart';
import 'package:bb_mobile/features/sell/domain/watch_payjoin_usecase.dart';
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

class _MockWatchPayjoin extends Mock implements WatchPayjoinUsecase {}

class _MockGetPayjoin extends Mock implements GetPayjoinUsecase {}

class _MockPreviewBitcoinFee extends Mock implements PreviewBitcoinFeeUsecase {}

class _MockPreviewBitcoinFeePresets extends Mock
    implements PreviewBitcoinFeePresetsUsecase {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

class _MockLabelCompletedSellOrderUsecase extends Mock
    implements LabelCompletedSellOrderUsecase {}

class _MockWallet extends Mock implements Wallet {}

class _MockSellOrder extends Mock implements SellOrder {}

class _FakeNewLabel extends Fake implements NewLabel {}

class _FakeLabel extends Fake implements Label {}

/// The confirmation path only ever runs from a [SellPaymentState] that earlier
/// events built up. Seeding it directly keeps this test to the send path and
/// avoids the order polling timer that order creation starts.
class _MockGetPayjoinTradingEnabled extends Mock
    implements GetPayjoinTradingEnabledUsecase {}

class _MockSetPayjoinTradingEnabled extends Mock
    implements SetPayjoinTradingEnabledUsecase {}

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
    required super.watchPayjoinUsecase,
    required super.getPayjoinUsecase,
    required super.getPayjoinTradingEnabledUsecase,
    required super.setPayjoinTradingEnabledUsecase,
    required super.getNetworkFeesUsecase,
    required super.calculateLiquidAbsoluteFeesUsecase,
    required super.calculateBitcoinAbsoluteFeesUsecase,
    required super.convertSatsToCurrencyAmountUsecase,
    required super.getAddressAtIndexUsecase,
    required super.getWalletUtxosUsecase,
    required super.getOrderUsecase,
    required super.labelsFacade,
    required super.labelCompletedSellOrderUsecase,
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
  late _MockWatchPayjoin watchPayjoin;
  late _MockGetPayjoin getPayjoin;
  late _MockGetPayjoinTradingEnabled getPayjoinTradingEnabled;
  late _MockRefreshSellOrder refreshSellOrder;
  late _MockLabelsFacade labelsFacade;
  late _MockLabelCompletedSellOrderUsecase labelCompletedSellOrder;
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
      Order.buy(
        orderId: 'fallback',
        orderType: OrderType.buy,
        message: OrderMessage(code: '', message: ''),
        orderNumber: 1,
        payinAmount: 100,
        payinCurrency: 'CAD',
        payoutAmount: 0.001,
        payoutCurrency: 'BTC',
        payinMethod: OrderPaymentMethod.cadBalance,
        payoutMethod: OrderPaymentMethod.bitcoin,
        orderStatus: OrderStatus.completed,
        payinStatus: OrderPayinStatus.completed,
        payoutStatus: OrderPayoutStatus.completed,
        confirmationDeadline: DateTime.utc(2026, 7, 29, 12, 5),
        createdAt: DateTime.utc(2026, 7, 29, 12),
        bitcoinAddress: 'bc1qbuy',
        bitcoinTransactionId: 'buy-txid',
        isTestnet: false,
      ),
    );
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
    watchPayjoin = _MockWatchPayjoin();
    when(
      () => watchPayjoin.execute(any()),
    ).thenAnswer((_) => const Stream.empty());
    getPayjoin = _MockGetPayjoin();
    when(() => getPayjoin.execute(any())).thenAnswer((_) async => null);
    getPayjoinTradingEnabled = _MockGetPayjoinTradingEnabled();
    when(
      () => getPayjoinTradingEnabled.execute(),
    ).thenAnswer((_) async => true);
    refreshSellOrder = _MockRefreshSellOrder();
    labelsFacade = _MockLabelsFacade();
    labelCompletedSellOrder = _MockLabelCompletedSellOrderUsecase();
    when(
      () => labelCompletedSellOrder.execute(order: any(named: 'order')),
    ).thenAnswer((_) async {});
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
    // The deposit-address pinning compares orders through this getter; the
    // default order carries the creation-time address.
    when(
      () => sellOrder.toAddress,
    ).thenReturn('bc1q0000000000000000000000000000000000000');
    // The post-broadcast completion only succeeds once the exchange sees the
    // payin; default to seen, tests that need otherwise re-stub it.
    when(() => sellOrder.payinStatus).thenReturn(OrderPayinStatus.inProgress);
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
      watchPayjoinUsecase: watchPayjoin,
      getPayjoinUsecase: getPayjoin,
      getPayjoinTradingEnabledUsecase: getPayjoinTradingEnabled,
      setPayjoinTradingEnabledUsecase: _MockSetPayjoinTradingEnabled(),
      getNetworkFeesUsecase: getNetworkFees,
      calculateLiquidAbsoluteFeesUsecase: _MockCalculateLiquidFees(),
      calculateBitcoinAbsoluteFeesUsecase: calculateBitcoinFees,
      convertSatsToCurrencyAmountUsecase: _MockConvertSatsToCurrency(),
      getAddressAtIndexUsecase: _MockGetAddressAtIndex(),
      getWalletUtxosUsecase: _MockGetWalletUtxos(),
      getOrderUsecase: getOrder,
      labelsFacade: labelsFacade,
      labelCompletedSellOrderUsecase: labelCompletedSellOrder,
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
    test('falls back to a plain payment when trading was disabled', () async {
      const bip21 =
          'bitcoin:bc1q0000000000000000000000000000000000000'
          '?amount=0.001&pj=https://payjo.in/session';
      when(() => sellOrder.bip21URI).thenReturn(bip21);
      when(
        () => getPayjoinTradingEnabled.execute(),
      ).thenAnswer((_) async => false);
      when(
        () => getOrder.execute(orderId: any(named: 'orderId')),
      ).thenAnswer((_) async => sellOrder);

      bloc.add(const SellEvent.sendPaymentConfirmed());
      await untilCalled(
        () => broadcastBitcoin.execute(any(), isPsbt: any(named: 'isPsbt')),
      );

      verifyNever(
        () => sendWithPayjoin.execute(
          walletId: any(named: 'walletId'),
          isTestnet: any(named: 'isTestnet'),
          bip21: any(named: 'bip21'),
          unsignedOriginalPsbt: any(named: 'unsignedOriginalPsbt'),
          amountSat: any(named: 'amountSat'),
          networkFeesSatPerVb: any(named: 'networkFeesSatPerVb'),
          expireAfterSec: any(named: 'expireAfterSec'),
        ),
      );
      expect((bloc.state as SellPaymentState).isPayjoinEnabled, isFalse);
    });

    test('audit reproducer (H6): a wallet selection during confirmation '
        'is ignored', () async {
      bloc.seed(
        (bloc.state as SellPaymentState).copyWith(isConfirmingPayment: true),
      );

      bloc.add(SellEvent.walletSelected(wallet: wallet));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        bloc.state,
        isA<SellPaymentState>(),
        reason:
            'tearing down the payment state mid-confirmation orphans the '
            'in-flight payment and lets a later payjoin resolution latch '
            'onto a different order',
      );
      expect((bloc.state as SellPaymentState).isConfirmingPayment, isTrue);
    });

    test('Payjoin toggle is ignored while confirmation is in flight', () async {
      bloc.seed(
        (bloc.state as SellPaymentState).copyWith(isConfirmingPayment: true),
      );

      bloc.add(const SellEvent.payjoinToggled(false));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect((bloc.state as SellPaymentState).isPayjoinEnabled, isTrue);
    });

    test(
      'does not report success while a Payjoin is only requested',
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

        // The order fetch must succeed, otherwise the premature success this test
        // guards against is hidden by a failing fetch rather than absent.
        when(
          () => getOrder.execute(orderId: any(named: 'orderId')),
        ).thenAnswer((_) async => sellOrder);

        bloc.add(const SellEvent.sendPaymentConfirmed());
        // Long enough to outlast the post-broadcast order fetch delay.
        await Future<void>.delayed(const Duration(seconds: 6));

        // Nothing is on the wire yet: the session is still negotiating, and its
        // original transaction is only broadcast if that negotiation fails.
        expect(bloc.state, isA<SellPaymentState>());
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );

    test('a failed Payjoin start whose session persisted is adopted, '
        'not surfaced as a retryable error', () async {
      const bip21 =
          'bitcoin:bc1q0000000000000000000000000000000000000'
          '?amount=0.001&pj=https://payjo.in/session';
      when(() => sellOrder.bip21URI).thenReturn(bip21);
      // The engine persists the session (signed original included) before
      // posting to the directory; a post failure throws AFTER that persist.
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
      ).thenThrow(SendPayjoinException('Failed to start Payjoin sale'));
      when(() => getPayjoin.execute(bip21)).thenAnswer(
        (_) async => PayjoinSenderSession(
          status: PayjoinStatus.started,
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
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // The persisted session WILL broadcast its original at the deadline.
      // Re-arming Confirm here would let a plain retry pay the same order
      // again on disjoint inputs (the session's inputs are reserved), so
      // the payment must stay latched on the adopted session instead.
      final state = bloc.state as SellPaymentState;
      expect(state.error, isNull);
      expect(
        state.isConfirmingPayment,
        isTrue,
        reason:
            'an adopted session keeps Confirm latched until the session '
            'resolves — re-arming it opens the double-payment window',
      );
      verify(() => watchPayjoin.execute(bip21)).called(1);
      verifyNever(
        () => broadcastBitcoin.execute(any(), isPsbt: any(named: 'isPsbt')),
      );
    });

    test('a failed Payjoin start with nothing persisted still surfaces the '
        'retryable error', () async {
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
      ).thenThrow(SendPayjoinException('Failed to start Payjoin sale'));
      // No session row: the failure happened before the write-ahead
      // persist, so nothing can broadcast later and retrying is safe.
      when(() => getPayjoin.execute(bip21)).thenAnswer((_) async => null);

      bloc.add(const SellEvent.sendPaymentConfirmed());
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = bloc.state as SellPaymentState;
      expect(state.error, isNotNull);
      expect(state.isConfirmingPayment, isFalse);
      verifyNever(() => watchPayjoin.execute(any()));
    });

    test(
      'a completed Payjoin settles the sale with its txid',
      () async {
        const bip21 =
            'bitcoin:bc1q0000000000000000000000000000000000000'
            '?amount=0.001&pj=https://payjo.in/session';
        const payjoinTxid =
            'aaaa1111c0ea01904322222851b2e702d37651be2644f4757cc4421f39261b55';
        when(() => sellOrder.bip21URI).thenReturn(bip21);
        when(
          () => getOrder.execute(orderId: any(named: 'orderId')),
        ).thenAnswer((_) async => sellOrder);
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
        when(() => watchPayjoin.execute(bip21)).thenAnswer(
          (_) => Stream.value(
            PayjoinSenderSession(
              status: PayjoinStatus.completed,
              uri: bip21,
              network: BitcoinNetwork.mainnet,
              walletId: 'wallet-1',
              originalTransactionId: expectedTxid,
              transactionId: payjoinTxid,
              amount: Sats.fromInt(100000),
              createdAt: DateTime(2026),
              expiresAt: DateTime(2026).add(const Duration(minutes: 5)),
            ),
          ),
        );

        bloc.add(const SellEvent.sendPaymentConfirmed());
        final settled = await bloc.stream.firstWhere(
          (state) => state is SellPaymentState && state.isPayinBroadcast,
        );

        // The payjoin transaction is the one that reached the chain, so it is the
        // txid the sale must carry — not the original it replaced.
        expect((settled as SellPaymentState).payinBroadcastTxid, payjoinTxid);
        await bloc.stream.firstWhere((state) => state is SellSuccessState);
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

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
      // The session is now watched rather than latched: nothing is on the wire
      // until it resolves.
      await untilCalled(() => watchPayjoin.execute(bip21));

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
        await untilCalled(() => watchPayjoin.execute(bip21));

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
          () => refreshedOrder.payinStatus,
        ).thenReturn(OrderPayinStatus.inProgress);
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
        () => refreshSellOrder.execute(
          orderId: any(named: 'orderId'),
          expectedDepositAddress: any(named: 'expectedDepositAddress'),
        ),
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
    // A benign refresh keeps the deposit address the order was created with.
    when(
      () => refreshedOrder.toAddress,
    ).thenReturn('bc1q0000000000000000000000000000000000000');
    when(
      () => refreshSellOrder.execute(
        orderId: any(named: 'orderId'),
        expectedDepositAddress: any(named: 'expectedDepositAddress'),
      ),
    ).thenAnswer((_) async => refreshedOrder);

    bloc.add(const SellEvent.sendPaymentConfirmed());
    await Future<void>.delayed(const Duration(milliseconds: 200));

    verify(
      () => refreshSellOrder.execute(
        orderId: 'order-1',
        expectedDepositAddress: 'bc1q0000000000000000000000000000000000000',
      ),
    ).called(1);
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

  group('SellBloc — deposit address pinning', () {
    /// A refresh response whose deposit address differs from the one the
    /// order was created with. Stands in for a compromised backend or a
    /// MITM rewriting the exchange API response.
    _MockSellOrder tamperedOrder() {
      final order = _MockSellOrder();
      when(() => order.orderId).thenReturn('order-1');
      when(() => order.payinAmount).thenReturn(0.001);
      when(
        () => order.toAddress,
      ).thenReturn('bc1qattacker00000000000000000000000000000');
      return order;
    }

    test('audit reproducer: a refreshed order carrying a different deposit '
        'address is refused, never adopted', () async {
      // Before the fix, _onOrderRefreshTimePassed replaced the whole order
      // unconditionally and the confirm screen never showed the address, so
      // a tampered refresh silently redirected the payin.
      when(
        () => refreshSellOrder.execute(
          orderId: any(named: 'orderId'),
          expectedDepositAddress: any(named: 'expectedDepositAddress'),
        ),
      ).thenThrow(const SellError.depositAddressChanged());

      bloc.add(const SellEvent.orderRefreshTimePassed());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = bloc.state as SellPaymentState;
      expect(
        state.sellOrder,
        same(sellOrder),
        reason:
            'a refreshed order with a different deposit address must never '
            'replace the order the payin is built from',
      );
      expect(state.error, isA<DepositAddressChangedSellError>());
    });

    test(
      'a refreshed order carrying the same deposit address is adopted',
      () async {
        final refreshedOrder = _MockSellOrder();
        when(() => refreshedOrder.orderId).thenReturn('order-1');
        // A new price lock moves the payin amount — that part of the refresh
        // must keep working.
        when(() => refreshedOrder.payinAmount).thenReturn(0.002);
        when(
          () => refreshedOrder.toAddress,
        ).thenReturn('bc1q0000000000000000000000000000000000000');
        when(
          () => refreshSellOrder.execute(
            orderId: any(named: 'orderId'),
            expectedDepositAddress: any(named: 'expectedDepositAddress'),
          ),
        ).thenAnswer((_) async => refreshedOrder);

        bloc.add(const SellEvent.orderRefreshTimePassed());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final state = bloc.state as SellPaymentState;
        expect(state.sellOrder, same(refreshedOrder));
        expect(state.error, isNull);
      },
    );

    test('a polled order carrying a different deposit address is refused '
        'while the payment is still unsigned', () async {
      // The periodic order poll is a second adoption path for a tampered
      // order: it merges the fetched order into the live payment state.
      final tampered = tamperedOrder();
      when(
        () => tampered.payinStatus,
      ).thenReturn(OrderPayinStatus.awaitingPayment);
      when(
        () => getOrder.execute(orderId: any(named: 'orderId')),
      ).thenAnswer((_) async => tampered);

      bloc.add(const SellEvent.pollOrderStatus());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = bloc.state as SellPaymentState;
      expect(state.sellOrder, same(sellOrder));
      expect(state.error, isA<DepositAddressChangedSellError>());
    });

    test(
      'a changed address is refused even when the poll reports progress',
      () async {
        final tampered = tamperedOrder();
        when(
          () => tampered.payinStatus,
        ).thenReturn(OrderPayinStatus.inProgress);
        when(
          () => getOrder.execute(orderId: any(named: 'orderId')),
        ).thenAnswer((_) async => tampered);

        bloc.add(const SellEvent.pollOrderStatus());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(bloc.state, isA<SellPaymentState>());
        expect(
          (bloc.state as SellPaymentState).error,
          isA<DepositAddressChangedSellError>(),
        );
      },
    );

    test('after a refused refresh, the payin still targets the creation-time '
        'address', () async {
      when(
        () => refreshSellOrder.execute(
          orderId: any(named: 'orderId'),
          expectedDepositAddress: any(named: 'expectedDepositAddress'),
        ),
      ).thenThrow(const SellError.depositAddressChanged());
      when(
        () => getOrder.execute(orderId: any(named: 'orderId')),
      ).thenAnswer((_) async => sellOrder);

      bloc.add(const SellEvent.orderRefreshTimePassed());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        (bloc.state as SellPaymentState).error,
        isA<DepositAddressChangedSellError>(),
      );

      bloc.add(const SellEvent.sendPaymentConfirmed());
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final builtAddresses = verify(
        () => prepareBitcoinSend.execute(
          walletId: any(named: 'walletId'),
          address: captureAny(named: 'address'),
          amountSat: any(named: 'amountSat'),
          networkFee: any(named: 'networkFee'),
          selectedInputs: any(named: 'selectedInputs'),
          replaceByFee: any(named: 'replaceByFee'),
        ),
      ).captured;
      expect(
        builtAddresses,
        everyElement('bc1q0000000000000000000000000000000000000'),
        reason:
            'the payin must only ever pay the address the order was created '
            'with',
      );

      // Let the confirmation settle so nothing emits after tearDown closes.
      await Future<void>.delayed(const Duration(seconds: 6));
    }, timeout: const Timeout(Duration(seconds: 60)));
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
