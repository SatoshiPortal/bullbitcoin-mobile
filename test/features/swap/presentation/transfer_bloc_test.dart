import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_presets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_network.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_record.dart';
import 'package:bb_mobile/features/swap/domain/usecases/create_order_swap_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_order_swap_quote_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_pending_order_swaps_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/mark_order_swap_broadcast_unknown_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/mark_order_swap_payin_broadcast_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/replace_prepared_order_swap_payin_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/refresh_order_swap_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/save_prepared_order_swap_payin_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/watch_order_swap_usecase.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetSettings extends Mock implements GetSettingsUsecase {}

class _MockGetWallets extends Mock implements GetWalletsUsecase {}

class _MockGetNetworkFees extends Mock implements GetNetworkFeesUsecase {}

class _MockPrepareBitcoin extends Mock implements PrepareBitcoinSendUsecase {}

class _MockPrepareLiquid extends Mock implements PrepareLiquidSendUsecase {}

class _MockCalculateBitcoin extends Mock
    implements CalculateBitcoinAbsoluteFeesUsecase {}

class _MockCalculateLiquid extends Mock
    implements CalculateLiquidAbsoluteFeesUsecase {}

class _MockGetWallet extends Mock implements GetWalletUsecase {}

class _MockSignBitcoin extends Mock implements SignBitcoinTxUsecase {}

class _MockSignLiquid extends Mock implements SignLiquidTxUsecase {}

class _MockBroadcastBitcoin extends Mock
    implements BroadcastBitcoinTransactionUsecase {}

class _MockBroadcastLiquid extends Mock
    implements BroadcastLiquidTransactionUsecase {}

class _MockVerifyChain extends Mock
    implements VerifyChainSwapAmountSendUsecase {}

class _MockGetQuote extends Mock implements GetOrderSwapQuoteUsecase {}

class _MockGetPendingOrders extends Mock
    implements GetPendingOrderSwapsUsecase {}

class _MockCreateOrder extends Mock implements CreateOrderSwapUsecase {}

class _MockSavePrepared extends Mock
    implements SavePreparedOrderSwapPayinUsecase {}

class _MockReplacePrepared extends Mock
    implements ReplacePreparedOrderSwapPayinUsecase {}

class _MockRefreshOrder extends Mock implements RefreshOrderSwapUsecase {}

class _MockMarkUnknown extends Mock
    implements MarkOrderSwapBroadcastUnknownUsecase {}

class _MockMarkBroadcast extends Mock
    implements MarkOrderSwapPayinBroadcastUsecase {}

class _MockWatchOrder extends Mock implements WatchOrderSwapUsecase {}

class _MockDetectBitcoin extends Mock implements DetectBitcoinStringUsecase {}

class _MockGetReceiveAddress extends Mock implements GetReceiveAddressUsecase {}

class _MockGetUtxos extends Mock implements GetWalletUtxosUsecase {}

class _MockConvertSats extends Mock
    implements ConvertSatsToCurrencyAmountUsecase {}

class _MockPreviewFee extends Mock implements PreviewBitcoinFeeUsecase {}

class _MockPreviewPresets extends Mock
    implements PreviewBitcoinFeePresetsUsecase {}

class _MockCheckConsolidation extends Mock
    implements CheckLiquidConsolidationUsecase {}

void main() {
  late _MockMarkUnknown markUnknown;
  late _MockMarkBroadcast markBroadcast;
  late _MockBroadcastBitcoin broadcastBitcoin;
  late _MockRefreshOrder refreshOrder;
  late _MockGetPendingOrders getPendingOrders;
  late _MockGetSettings getSettings;
  late _MockGetWallets getWallets;
  late _MockGetNetworkFees getNetworkFees;
  late _MockConvertSats convertSats;
  late _MockWatchOrder watchOrder;
  late _MockGetWallet getWallet;
  late OrderSwapRecord prepared;
  late TransferBloc bloc;

  setUp(() {
    markUnknown = _MockMarkUnknown();
    markBroadcast = _MockMarkBroadcast();
    broadcastBitcoin = _MockBroadcastBitcoin();
    refreshOrder = _MockRefreshOrder();
    getPendingOrders = _MockGetPendingOrders();
    getSettings = _MockGetSettings();
    getWallets = _MockGetWallets();
    getNetworkFees = _MockGetNetworkFees();
    convertSats = _MockConvertSats();
    watchOrder = _MockWatchOrder();
    getWallet = _MockGetWallet();
    prepared = _prepared();
    when(
      () => getWallet.execute('wallet-1', sync: true),
    ).thenAnswer((_) async => _wallet());

    bloc = TransferBloc(
      getSettingsUsecase: getSettings,
      getWalletsUsecase: getWallets,
      getNetworkFeesUsecase: getNetworkFees,
      prepareBitcoinSendUsecase: _MockPrepareBitcoin(),
      prepareLiquidSendUsecase: _MockPrepareLiquid(),
      calculateBitcoinAbsoluteFeesUsecase: _MockCalculateBitcoin(),
      calculateLiquidAbsoluteFeesUsecase: _MockCalculateLiquid(),
      getWalletUsecase: getWallet,
      signBitcoinTxUsecase: _MockSignBitcoin(),
      signLiquidTxUsecase: _MockSignLiquid(),
      broadcastBitcoinTxUsecase: broadcastBitcoin,
      broadcastLiquidTxUsecase: _MockBroadcastLiquid(),
      verifyChainSwapAmountSendUsecase: _MockVerifyChain(),
      getOrderSwapQuoteUsecase: _MockGetQuote(),
      getPendingOrderSwapsUsecase: getPendingOrders,
      createOrderSwapUsecase: _MockCreateOrder(),
      savePreparedOrderSwapPayinUsecase: _MockSavePrepared(),
      replacePreparedOrderSwapPayinUsecase: _MockReplacePrepared(),
      refreshOrderSwapUsecase: refreshOrder,
      markOrderSwapBroadcastUnknownUsecase: markUnknown,
      markOrderSwapPayinBroadcastUsecase: markBroadcast,
      watchOrderSwapUsecase: watchOrder,
      detectBitcoinStringUsecase: _MockDetectBitcoin(),
      getReceiveAddressUsecase: _MockGetReceiveAddress(),
      getWalletUtxosUsecase: _MockGetUtxos(),
      convertSatsToCurrencyAmountUsecase: convertSats,
      previewBitcoinFeeUsecase: _MockPreviewFee(),
      previewBitcoinFeePresetsUsecase: _MockPreviewPresets(),
      checkLiquidConsolidationUsecase: _MockCheckConsolidation(),
    );
  });

  tearDown(() => bloc.close());

  test(
    'broadcasts a prepared order swap and emits its transaction id',
    () async {
      final broadcasting = _prepared(
        status: OrderSwapLocalStatus.broadcastUnknown,
      );
      final broadcasted = _prepared(
        status: OrderSwapLocalStatus.payinBroadcast,
        transactionId: 'txid-1',
      );
      when(
        () => markUnknown.execute('local-1'),
      ).thenAnswer((_) async => Ok(broadcasting));
      when(
        () => refreshOrder.execute('local-1'),
      ).thenAnswer((_) async => Ok(broadcasting));
      when(
        () => broadcastBitcoin.execute('signed-psbt', isPsbt: true),
      ).thenAnswer((_) async => 'txid-1');
      when(
        () =>
            markBroadcast.execute(localId: 'local-1', transactionId: 'txid-1'),
      ).thenAnswer((_) async => Ok(broadcasted));
      bloc.emit(
        TransferState(
          orderSwap: prepared,
          signedPsbt: 'signed-psbt',
          fromWallet: _wallet(),
          swap: _swap(),
        ),
      );
      final states = <TransferState>[];
      final subscription = bloc.stream.listen(states.add);
      final completed = bloc.stream.firstWhere(
        (state) => state.txId == 'txid-1',
      );
      bloc.add(const TransferEvent.confirmed());
      await completed;
      await subscription.cancel();
      verify(() => markUnknown.execute('local-1')).called(1);
      verify(
        () => broadcastBitcoin.execute('signed-psbt', isPsbt: true),
      ).called(1);
      verify(
        () =>
            markBroadcast.execute(localId: 'local-1', transactionId: 'txid-1'),
      ).called(1);
      expect(bloc.state.txId, 'txid-1');
      expect(states.any((state) => state.txId == 'txid-1'), isTrue);
    },
  );

  test('resumes a stored prepared transfer on start', () async {
    final settings = SettingsEntity(
      environment: Environment.testnet,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'USD',
    );
    when(() => getSettings.execute()).thenAnswer((_) async => settings);
    when(
      () => getPendingOrders.execute(),
    ).thenAnswer((_) async => Ok([prepared]));
    when(
      () => getWallets.execute(),
    ).thenAnswer((_) async => [_liquidWallet(), _destinationWallet()]);
    when(
      () => getNetworkFees.execute(isLiquid: any(named: 'isLiquid')),
    ).thenAnswer((_) async => _feeOptions());
    when(
      () => convertSats.execute(currencyCode: 'USD'),
    ).thenAnswer((_) async => 1.0);
    when(
      () => watchOrder.execute('local-1'),
    ).thenAnswer((_) => const Stream.empty());

    bloc.add(const TransferEvent.started());
    await bloc.stream.firstWhere((state) => !state.isStarting);

    expect(bloc.state.orderSwap, prepared);
    expect(bloc.state.signedPsbt, 'signed-psbt');
    expect(bloc.state.swap, isA<ChainSwap>());
  });

  test('resumes a stored transfer in the configured BTC unit', () async {
    final settings = SettingsEntity(
      environment: Environment.testnet,
      bitcoinUnit: BitcoinUnit.btc,
      currencyCode: 'USD',
    );
    when(() => getSettings.execute()).thenAnswer((_) async => settings);
    when(
      () => getPendingOrders.execute(),
    ).thenAnswer((_) async => Ok([prepared]));
    when(
      () => getWallets.execute(),
    ).thenAnswer((_) async => [_liquidWallet(), _destinationWallet()]);
    when(
      () => getNetworkFees.execute(isLiquid: any(named: 'isLiquid')),
    ).thenAnswer((_) async => _feeOptions());
    when(
      () => convertSats.execute(currencyCode: 'USD'),
    ).thenAnswer((_) async => 1.0);
    when(
      () => watchOrder.execute('local-1'),
    ).thenAnswer((_) => const Stream.empty());

    bloc.add(const TransferEvent.started());
    await bloc.stream.firstWhere((state) => !state.isStarting);

    expect(bloc.state.amount, '0.00001');
    expect(bloc.state.inputAmountSat, 1000);
  });

  test('resumes the persisted non-default wallet pair', () async {
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    when(
      () => getPendingOrders.execute(),
    ).thenAnswer((_) async => Ok([prepared]));
    when(() => getWallets.execute()).thenAnswer(
      (_) async => [
        _liquidWallet(id: 'default-liquid', isDefault: true),
        _liquidWallet(),
        _destinationWallet(id: 'default-bitcoin', isDefault: true),
        _destinationWallet(),
      ],
    );
    when(
      () => getNetworkFees.execute(isLiquid: any(named: 'isLiquid')),
    ).thenAnswer((_) async => _feeOptions());
    when(
      () => convertSats.execute(currencyCode: 'USD'),
    ).thenAnswer((_) async => 1.0);
    when(
      () => watchOrder.execute('local-1'),
    ).thenAnswer((_) => const Stream.empty());

    bloc.add(const TransferEvent.started());
    await bloc.stream.firstWhere((state) => !state.isStarting);

    expect(bloc.state.fromWallet?.id, 'wallet-1');
    expect(bloc.state.toWallet?.id, 'wallet-2');
    expect(bloc.state.orderSwap?.localId, 'local-1');
  });

  test('surfaces a typed failure from the order watcher', () async {
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    when(
      () => getPendingOrders.execute(),
    ).thenAnswer((_) async => Ok([prepared]));
    when(
      () => getWallets.execute(),
    ).thenAnswer((_) async => [_liquidWallet(), _destinationWallet()]);
    when(
      () => getNetworkFees.execute(isLiquid: any(named: 'isLiquid')),
    ).thenAnswer((_) async => _feeOptions());
    when(
      () => convertSats.execute(currencyCode: 'USD'),
    ).thenAnswer((_) async => 1.0);
    when(() => watchOrder.execute('local-1')).thenAnswer(
      (_) =>
          Stream.value(const Err(SwapStorageFailure('database unavailable'))),
    );

    bloc.add(const TransferEvent.started());
    await bloc.stream.firstWhere((state) => state.swapFailure != null);

    expect(bloc.state.swapFailure, isA<SwapStorageFailure>());
  });

  test(
    'refreshes an unknown broadcast and skips rebroadcast when payin is seen',
    () async {
      final unknown = _prepared(status: OrderSwapLocalStatus.broadcastUnknown);
      final refreshed = _prepared(
        status: OrderSwapLocalStatus.payoutInProgress,
        payinStatus: 'Completed',
      );
      when(
        () => refreshOrder.execute('local-1'),
      ).thenAnswer((_) async => Ok(refreshed));
      bloc.emit(
        TransferState(
          orderSwap: unknown,
          signedPsbt: 'signed-psbt',
          fromWallet: _wallet(),
          swap: _swap(),
        ),
      );

      bloc.add(const TransferEvent.confirmed());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verify(() => refreshOrder.execute('local-1')).called(1);
      verifyNever(() => markUnknown.execute(any()));
      verifyNever(
        () => broadcastBitcoin.execute(any(), isPsbt: any(named: 'isPsbt')),
      );
      expect(bloc.state.orderSwap, refreshed);
    },
  );

  test(
    'surfaces an expired stored transfer without a broadcast transaction',
    () async {
      final expired = _prepared(
        order: _order(deadline: DateTime.utc(2026, 1, 1, 0, 5)),
      );
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.testnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      );
      when(
        () => getPendingOrders.execute(),
      ).thenAnswer((_) async => Ok([expired]));
      when(
        () => getWallets.execute(),
      ).thenAnswer((_) async => [_liquidWallet(), _destinationWallet()]);
      when(
        () => getNetworkFees.execute(isLiquid: any(named: 'isLiquid')),
      ).thenAnswer((_) async => _feeOptions());
      when(
        () => convertSats.execute(currencyCode: 'USD'),
      ).thenAnswer((_) async => 1.0);

      bloc.add(const TransferEvent.started());
      await bloc.stream.firstWhere((state) => !state.isStarting);

      expect(bloc.state.orderSwap, expired);
      expect(bloc.state.swap?.status, SwapStatus.expired);
      expect(bloc.state.signedPsbt, isEmpty);
      bloc.add(const TransferEvent.confirmed());
      await Future<void>.delayed(Duration.zero);
      verifyNever(
        () => broadcastBitcoin.execute(any(), isPsbt: any(named: 'isPsbt')),
      );
    },
  );

  test(
    'surfaces a broadcast network failure without raw exception text',
    () async {
      when(
        () => markUnknown.execute('local-1'),
      ).thenAnswer((_) async => Ok(prepared));
      when(
        () => broadcastBitcoin.execute('signed-psbt', isPsbt: true),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/broadcast'),
          message: 'broadcast failed',
        ),
      );
      bloc.emit(
        TransferState(
          orderSwap: prepared,
          signedPsbt: 'signed-psbt',
          fromWallet: _wallet(),
          swap: _swap(),
        ),
      );
      bloc.add(const TransferEvent.confirmed());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.swapFailure, isA<SwapNetworkFailure>());
      expect(bloc.state.confirmTransactionException, isNull);
      expect(bloc.state.swapFailure!.logMessage, isNull);
    },
  );

  test('preserves a typed swap failure while confirming', () async {
    when(
      () => markUnknown.execute('local-1'),
    ).thenAnswer((_) async => const Err(SwapOrderExpiredFailure('expired')));
    bloc.emit(
      TransferState(
        orderSwap: prepared,
        signedPsbt: 'signed-psbt',
        fromWallet: _wallet(),
        swap: _swap(),
      ),
    );

    bloc.add(const TransferEvent.confirmed());
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.swapFailure, isA<SwapOrderExpiredFailure>());
  });
}

OrderSwapRecord _prepared({
  OrderSwapLocalStatus status = OrderSwapLocalStatus.readyToBroadcast,
  String? transactionId,
  String payinStatus = 'In progress',
  OrderSwap? order,
}) => OrderSwapRecord(
  localId: 'local-1',
  purpose: OrderSwapPurpose.transfer,
  environment: OrderSwapEnvironment.testnet,
  inNetwork: OrderSwapNetwork.liquid,
  outNetwork: OrderSwapNetwork.bitcoin,
  isInAmountFixed: false,
  requestedAmountSat: BigInt.from(1000),
  sourceWalletId: 'wallet-1',
  destinationWalletId: 'wallet-2',
  destination: 'destination',
  fallback: 'fallback',
  order: order ?? _order(payinStatus: payinStatus),
  createdAt: DateTime.utc(2026),
  localStatus: status,
  localPayinTransactionId: transactionId,
  signedPayinTransaction: 'signed-psbt',
  payinIsPsbt: true,
);

OrderSwap _order({String payinStatus = 'In progress', DateTime? deadline}) =>
    OrderSwap(
      orderId: 'order-1',
      orderNumber: 1,
      inNetwork: OrderSwapNetwork.liquid,
      outNetwork: OrderSwapNetwork.bitcoin,
      payinAmountSat: BigInt.from(1010),
      payoutAmountSat: BigInt.from(1000),
      payinCurrency: 'LBTC',
      payoutCurrency: 'BTC',
      payinMethod: 'Liquid',
      payoutMethod: 'Bitcoin',
      orderType: 'Swap',
      orderStatus: 'Awaiting payment',
      payinStatus: payinStatus,
      payoutStatus: 'Not started',
      messageCode: 'ORDER_CREATED',
      bitcoinAddress: 'destination',
      liquidAddress: 'liquid-address',
      createdAt: DateTime.utc(2026),
      confirmationDeadline:
          deadline ?? DateTime.now().toUtc().add(const Duration(days: 365)),
    );

ChainSwap _swap() =>
    Swap.chain(
          id: 'swap-1',
          keyIndex: 0,
          type: SwapType.bitcoinToLiquid,
          status: SwapStatus.pending,
          environment: Environment.testnet,
          creationTime: DateTime.utc(2026),
          sendWalletId: 'wallet-1',
          paymentAddress: 'payin-address',
          paymentAmount: 1000,
        )
        as ChainSwap;

Wallet _wallet() => Wallet(
  origin: 'wallet-1',
  network: Network.bitcoinTestnet,
  xpubFingerprint: 'fingerprint',
  scriptType: ScriptType.bip84,
  xpub: 'xpub',
  externalPublicDescriptor: 'external',
  internalPublicDescriptor: 'internal',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);

Wallet _liquidWallet({String id = 'wallet-1', bool isDefault = false}) =>
    Wallet(
      origin: id,
      network: Network.liquidTestnet,
      xpubFingerprint: 'fingerprint-1',
      scriptType: ScriptType.bip84,
      xpub: 'xpub-1',
      externalPublicDescriptor: 'external-1',
      internalPublicDescriptor: 'internal-1',
      signer: SignerEntity.local,
      signerDevice: null,
      isDefault: isDefault,
      balanceSat: BigInt.zero,
    );

Wallet _destinationWallet({String id = 'wallet-2', bool isDefault = false}) =>
    Wallet(
      origin: id,
      network: Network.bitcoinTestnet,
      xpubFingerprint: 'fingerprint-2',
      scriptType: ScriptType.bip84,
      xpub: 'xpub-2',
      externalPublicDescriptor: 'external-2',
      internalPublicDescriptor: 'internal-2',
      signer: SignerEntity.local,
      signerDevice: null,
      isDefault: isDefault,
      balanceSat: BigInt.from(2000),
    );

FeeOptions _feeOptions() => const FeeOptions(
  fastest: RelativeFee(250),
  economic: RelativeFee(250),
  slow: RelativeFee(250),
  minRelay: RelativeFee(25),
);
