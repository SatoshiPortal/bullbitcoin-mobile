import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/fees/domain/fee_preview_cache.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/validate_bitcoin_selection_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/insufficient_funds_exception.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
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
import 'package:bb_mobile/features/swap/presentation/transfer_confirm_error.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetSettings extends Mock implements GetSettingsUsecase {}

class _MockGetWallets extends Mock implements GetWalletsUsecase {}

class _MockGetNetworkFees extends Mock implements GetNetworkFeesUsecase {}

class _MockPrepareBitcoin extends Mock implements PrepareBitcoinSendUsecase {}

class _MockValidateBitcoinSelection extends Mock
    implements ValidateBitcoinSelectionUsecase {}

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
  setUpAll(() {
    registerFallbackValue(const RelativeFee(250));
  });

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
  late _MockPrepareBitcoin prepareBitcoin;
  late _MockValidateBitcoinSelection validateBitcoinSelection;
  late _MockCalculateBitcoin calculateBitcoin;
  late _MockGetReceiveAddress getReceiveAddress;
  late _MockGetUtxos getUtxos;
  late _MockSignBitcoin signBitcoin;
  late _MockReplacePrepared replacePrepared;
  late _MockVerifyChain verifyChain;
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
    prepareBitcoin = _MockPrepareBitcoin();
    validateBitcoinSelection = _MockValidateBitcoinSelection();
    calculateBitcoin = _MockCalculateBitcoin();
    getReceiveAddress = _MockGetReceiveAddress();
    getUtxos = _MockGetUtxos();
    signBitcoin = _MockSignBitcoin();
    replacePrepared = _MockReplacePrepared();
    verifyChain = _MockVerifyChain();
    prepared = _prepared();
    when(
      () => getWallet.execute('wallet-1', sync: true),
    ).thenAnswer((_) async => _wallet());
    when(
      () => validateBitcoinSelection.execute(
        walletId: any(named: 'walletId'),
        selectedInputs: any(named: 'selectedInputs'),
      ),
    ).thenAnswer((_) async => []);

    bloc = TransferBloc(
      getSettingsUsecase: getSettings,
      getWalletsUsecase: getWallets,
      getNetworkFeesUsecase: getNetworkFees,
      prepareBitcoinSendUsecase: prepareBitcoin,
      validateBitcoinSelectionUsecase: validateBitcoinSelection,
      prepareLiquidSendUsecase: _MockPrepareLiquid(),
      calculateBitcoinAbsoluteFeesUsecase: calculateBitcoin,
      calculateLiquidAbsoluteFeesUsecase: _MockCalculateLiquid(),
      getWalletUsecase: getWallet,
      signBitcoinTxUsecase: signBitcoin,
      signLiquidTxUsecase: _MockSignLiquid(),
      broadcastBitcoinTxUsecase: broadcastBitcoin,
      broadcastLiquidTxUsecase: _MockBroadcastLiquid(),
      verifyChainSwapAmountSendUsecase: verifyChain,
      getOrderSwapQuoteUsecase: _MockGetQuote(),
      getPendingOrderSwapsUsecase: getPendingOrders,
      createOrderSwapUsecase: _MockCreateOrder(),
      savePreparedOrderSwapPayinUsecase: _MockSavePrepared(),
      replacePreparedOrderSwapPayinUsecase: replacePrepared,
      refreshOrderSwapUsecase: refreshOrder,
      markOrderSwapBroadcastUnknownUsecase: markUnknown,
      markOrderSwapPayinBroadcastUsecase: markBroadcast,
      watchOrderSwapUsecase: watchOrder,
      detectBitcoinStringUsecase: _MockDetectBitcoin(),
      getReceiveAddressUsecase: getReceiveAddress,
      getWalletUtxosUsecase: getUtxos,
      convertSatsToCurrencyAmountUsecase: convertSats,
      previewBitcoinFeeUsecase: _MockPreviewFee(),
      previewBitcoinFeePresetsUsecase: _MockPreviewPresets(),
      checkLiquidConsolidationUsecase: _MockCheckConsolidation(),
    );
  });

  tearDown(() => bloc.close());

  test(
    'exposes insufficient funds when same-chain creation raises a shortfall',
    () async {
      final source = _wallet(balanceSat: BigInt.from(2000));
      final destination = _destinationWallet();
      when(
        () => prepareBitcoin.execute(
          walletId: source.id,
          address: any(named: 'address'),
          amountSat: 1000,
          networkFee: any(named: 'networkFee'),
          drain: false,
          selectedInputs: any(named: 'selectedInputs'),
          replaceByFee: true,
        ),
      ).thenThrow(InsufficientFundsException('shortfall'));
      bloc.emit(
        TransferState(
          fromWallet: source,
          toWallet: destination,
          receiveAddress: 'tb1qdestination',
          bitcoinUnit: BitcoinUnit.sats,
          bitcoinNetworkFees: _feeOptions(),
        ),
      );

      bloc.add(const TransferEvent.swapCreated('1000'));
      await bloc.stream.firstWhere((state) => !state.isCreatingSwap);

      expect(
        bloc.state.swapCreationException,
        isA<InsufficientFundsSwapException>(),
      );
    },
  );

  test(
    'maps selected-coin rebuild shortfall to the insufficient code',
    () async {
      final selected = _bitcoinUtxo('selected-tx');
      when(
        () => prepareBitcoin.execute(
          walletId: 'wallet-1',
          address: 'tb1qreceive',
          amountSat: 1000,
          networkFee: any(named: 'networkFee'),
          drain: false,
          selectedInputs: [selected],
          replaceByFee: true,
        ),
      ).thenThrow(InsufficientFundsException('shortfall'));
      bloc.emit(
        TransferState(
          fromWallet: _wallet(balanceSat: BigInt.from(100000)),
          toWallet: _destinationWallet(),
          receiveAddress: 'tb1qreceive',
          amount: '1000',
          selectedUtxos: [selected],
          signedPsbt: 'stale-psbt',
          bitcoinNetworkFees: _feeOptions(),
        ),
      );

      bloc.add(const TransferEvent.feeOptionSelected(FeeSelection.fastest));
      await bloc.stream.firstWhere(
        (state) => state.buildTransactionException != null,
      );

      expect(
        bloc.state.buildTransactionException?.message,
        selectedCoinsInsufficientCode,
      );
    },
  );

  test('maps unavailable selected coins in the cached rebuild path', () async {
    final selected = _bitcoinUtxo('selected-tx');
    when(
      () => validateBitcoinSelection.execute(
        walletId: 'wallet-1',
        selectedInputs: [selected],
      ),
    ).thenThrow(NoSpendableUtxoException('selected coin disappeared'));
    bloc.emit(
      TransferState(
        fromWallet: _wallet(balanceSat: BigInt.from(100000)),
        toWallet: _destinationWallet(),
        receiveAddress: 'tb1qreceive',
        amount: '1000',
        selectedUtxos: [selected],
        bitcoinNetworkFees: _feeOptions(),
        feePreviewCache: const BitcoinFeePreviewCache(
          fastest: BitcoinFeePreviewSlot(
            feeSat: 250,
            unsignedPsbt: 'cached-unsigned-psbt',
            txSize: 100,
          ),
        ),
      ),
    );

    bloc.add(const TransferEvent.feeOptionSelected(FeeSelection.fastest));
    await bloc.stream.firstWhere(
      (state) => state.buildTransactionException != null,
    );

    expect(
      bloc.state.buildTransactionException?.message,
      selectedCoinsUnavailableCode,
    );
  });

  test(
    'maps unavailable selected coins in the non-cached rebuild path',
    () async {
      final selected = _bitcoinUtxo('selected-tx');
      when(
        () => prepareBitcoin.execute(
          walletId: 'wallet-1',
          address: 'tb1qreceive',
          amountSat: 1000,
          networkFee: any(named: 'networkFee'),
          drain: false,
          selectedInputs: [selected],
          replaceByFee: true,
        ),
      ).thenThrow(NoSpendableUtxoException('selected coin disappeared'));
      bloc.emit(
        TransferState(
          fromWallet: _wallet(balanceSat: BigInt.from(100000)),
          toWallet: _destinationWallet(),
          receiveAddress: 'tb1qreceive',
          amount: '1000',
          selectedUtxos: [selected],
          signedPsbt: 'stale-psbt',
          bitcoinNetworkFees: _feeOptions(),
        ),
      );

      bloc.add(const TransferEvent.feeOptionSelected(FeeSelection.fastest));
      await bloc.stream.firstWhere(
        (state) => state.buildTransactionException != null,
      );

      expect(
        bloc.state.buildTransactionException?.message,
        selectedCoinsUnavailableCode,
      );
      expect(bloc.state.signedPsbt, isEmpty);
      verifyNever(
        () => broadcastBitcoin.execute(any(), isPsbt: any(named: 'isPsbt')),
      );
    },
  );

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

  test('Transfer MAX prices and builds from the selected UTXOs', () async {
    final selected = WalletUtxo.bitcoin(
      walletId: 'wallet-1',
      txId: 'selected-tx',
      vout: 2,
      scriptPubkey: Uint8List(0),
      amountSat: BigInt.from(30000),
      address: 'tb1qselected',
    );
    when(() => getReceiveAddress.execute(walletId: 'wallet-1')).thenAnswer(
      (_) async => WalletAddress(
        walletId: 'wallet-1',
        index: 0,
        address: 'tb1qreceive',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    when(
      () => prepareBitcoin.execute(
        walletId: 'wallet-1',
        address: 'tb1qreceive',
        networkFee: any(named: 'networkFee'),
        amountSat: any(named: 'amountSat'),
        drain: true,
        selectedInputs: [selected],
        replaceByFee: true,
      ),
    ).thenAnswer(
      (_) async => (unsignedPsbt: 'psbt', txSize: 100, isToSelf: false),
    );
    when(
      () => calculateBitcoin.execute(psbt: 'psbt'),
    ).thenAnswer((_) async => 1200);
    bloc.emit(
      TransferState(
        fromWallet: _wallet(balanceSat: BigInt.from(130000)),
        bitcoinNetworkFees: _feeOptions(),
        selectedUtxos: [selected],
      ),
    );

    expect(
      await bloc.getMaxAmountSat(_wallet(balanceSat: BigInt.from(130000))),
      28800,
    );
    verify(
      () => prepareBitcoin.execute(
        walletId: 'wallet-1',
        address: 'tb1qreceive',
        networkFee: any(named: 'networkFee'),
        amountSat: any(named: 'amountSat'),
        drain: true,
        selectedInputs: [selected],
        replaceByFee: true,
      ),
    ).called(1);
  });

  test('coin selection recomputes an active Transfer MAX', () async {
    final selected = WalletUtxo.bitcoin(
      walletId: 'wallet-1',
      txId: 'selected-tx',
      vout: 2,
      scriptPubkey: Uint8List(0),
      amountSat: BigInt.from(30000),
      address: 'tb1qselected',
    );
    when(() => getReceiveAddress.execute(walletId: 'wallet-1')).thenAnswer(
      (_) async => WalletAddress(
        walletId: 'wallet-1',
        index: 0,
        address: 'tb1qreceive',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    when(
      () => prepareBitcoin.execute(
        walletId: 'wallet-1',
        address: 'tb1qreceive',
        networkFee: any(named: 'networkFee'),
        amountSat: any(named: 'amountSat'),
        drain: true,
        selectedInputs: [selected],
        replaceByFee: true,
      ),
    ).thenAnswer(
      (_) async => (unsignedPsbt: 'psbt', txSize: 100, isToSelf: false),
    );
    when(
      () => calculateBitcoin.execute(psbt: 'psbt'),
    ).thenAnswer((_) async => 1200);
    bloc.emit(
      TransferState(
        fromWallet: _wallet(balanceSat: BigInt.from(130000)),
        toWallet: _liquidWallet(id: 'liquid-wallet'),
        bitcoinNetworkFees: _feeOptions(),
        maxAmountSat: 128800,
        amount: '128800',
      ),
    );

    bloc.add(TransferEvent.utxosSelected([selected]));
    await bloc.stream.firstWhere((state) => state.maxAmountSat == 28800);

    expect(bloc.state.amount, '28800');
    expect(bloc.state.isMaxSelected, isTrue);
    expect(bloc.state.selectedUtxos, [selected]);
  });

  test(
    'Transfer MAX clamps a selected balance below the fee to zero',
    () async {
      final selected = WalletUtxo.bitcoin(
        walletId: 'wallet-1',
        txId: 'selected-tx',
        vout: 2,
        scriptPubkey: Uint8List(0),
        amountSat: BigInt.from(1000),
        address: 'tb1qselected',
      );
      when(() => getReceiveAddress.execute(walletId: 'wallet-1')).thenAnswer(
        (_) async => WalletAddress(
          walletId: 'wallet-1',
          index: 0,
          address: 'tb1qreceive',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      when(
        () => prepareBitcoin.execute(
          walletId: 'wallet-1',
          address: 'tb1qreceive',
          networkFee: any(named: 'networkFee'),
          amountSat: any(named: 'amountSat'),
          drain: true,
          selectedInputs: [selected],
          replaceByFee: true,
        ),
      ).thenAnswer(
        (_) async => (unsignedPsbt: 'psbt', txSize: 100, isToSelf: false),
      );
      when(
        () => calculateBitcoin.execute(psbt: 'psbt'),
      ).thenAnswer((_) async => 1200);
      bloc.emit(
        TransferState(
          fromWallet: _wallet(balanceSat: BigInt.from(130000)),
          bitcoinNetworkFees: _feeOptions(),
          selectedUtxos: [selected],
        ),
      );

      expect(
        await bloc.getMaxAmountSat(_wallet(balanceSat: BigInt.from(130000))),
        0,
      );
    },
  );

  test(
    'a failed selection rebuild cannot broadcast the previous PSBT',
    () async {
      final oldSelection = WalletUtxo.bitcoin(
        walletId: 'wallet-1',
        txId: 'old-selected-tx',
        vout: 0,
        scriptPubkey: Uint8List(0),
        amountSat: BigInt.from(30000),
        address: 'tb1qold',
      );
      final unavailableSelection = WalletUtxo.bitcoin(
        walletId: 'wallet-1',
        txId: 'unavailable-selected-tx',
        vout: 1,
        scriptPubkey: Uint8List(0),
        amountSat: BigInt.from(1000),
        address: 'tb1qunavailable',
      );
      when(
        () => prepareBitcoin.execute(
          walletId: 'wallet-1',
          address: 'tb1qreceive',
          networkFee: any(named: 'networkFee'),
          amountSat: 1000,
          drain: false,
          selectedInputs: [unavailableSelection],
          replaceByFee: true,
        ),
      ).thenThrow(InsufficientFundsException('selected coin unavailable'));
      bloc.emit(
        TransferState(
          fromWallet: _wallet(),
          toWallet: _destinationWallet(),
          receiveAddress: 'tb1qreceive',
          amount: '1000',
          bitcoinNetworkFees: _feeOptions(),
          selectedUtxos: [oldSelection],
          signedPsbt: 'old-signed-psbt',
        ),
      );

      bloc.add(TransferEvent.utxosSelected([unavailableSelection]));
      await pumpEventQueue();
      bloc.add(const TransferEvent.confirmed());
      await pumpEventQueue();

      expect(bloc.state.signedPsbt, isEmpty);
      expect(bloc.state.buildTransactionException, isNotNull);
      verifyNever(
        () => broadcastBitcoin.execute('old-signed-psbt', isPsbt: true),
      );
    },
  );

  test('freezing a selected coin invalidates the staged PSBT', () async {
    final selected = WalletUtxo.bitcoin(
      walletId: 'wallet-1',
      txId: 'selected-tx',
      vout: 2,
      scriptPubkey: Uint8List(0),
      amountSat: BigInt.from(30000),
      address: 'tb1qselected',
    );
    final frozen = selected.copyWith(isFrozen: true);
    when(
      () => getUtxos.execute(walletId: 'wallet-1'),
    ).thenAnswer((_) async => [frozen]);
    bloc.emit(
      TransferState(
        fromWallet: _wallet(),
        selectedUtxos: [selected],
        utxos: [selected],
        signedPsbt: 'old-signed-psbt',
      ),
    );

    bloc.add(const TransferEvent.loadUtxos());
    await pumpEventQueue();

    expect(bloc.state.signedPsbt, isEmpty);
    expect(bloc.state.selectedUtxos, [selected]);
    expect(bloc.state.buildTransactionException, isNotNull);
  });

  test(
    'a newly reserved selected coin invalidates the cached PSBT before confirm',
    () async {
      final selected = WalletUtxo.bitcoin(
        walletId: 'wallet-1',
        txId: 'selected-tx',
        vout: 2,
        scriptPubkey: Uint8List(0),
        amountSat: BigInt.from(30000),
        address: 'tb1qselected',
      );
      when(
        () => validateBitcoinSelection.execute(
          walletId: 'wallet-1',
          selectedInputs: [selected],
        ),
      ).thenThrow(InsufficientFundsException('reserved'));
      bloc.emit(
        TransferState(
          fromWallet: _wallet(),
          toWallet: _destinationWallet(),
          receiveAddress: 'tb1qreceive',
          amount: '1000',
          bitcoinNetworkFees: _feeOptions(),
          selectedUtxos: [selected],
          utxos: [selected],
          signedPsbt: 'old-signed-psbt',
          feePreviewCache: const BitcoinFeePreviewCache(
            fastest: BitcoinFeePreviewSlot(
              feeSat: 250,
              unsignedPsbt: 'old-unsigned-psbt',
              txSize: 100,
            ),
          ),
        ),
      );

      bloc.add(const TransferEvent.confirmed());
      await pumpEventQueue();

      expect(bloc.state.signedPsbt, isEmpty);
      expect(bloc.state.feePreviewCache.fastest.isCacheReady, isFalse);
      expect(bloc.state.buildTransactionException, isNotNull);
      verifyNever(
        () => broadcastBitcoin.execute('old-signed-psbt', isPsbt: true),
      );
    },
  );

  test(
    'maps unavailable selected coins during confirm and clears fee previews',
    () async {
      final selected = _bitcoinUtxo('selected-tx');
      when(
        () => validateBitcoinSelection.execute(
          walletId: 'wallet-1',
          selectedInputs: [selected],
        ),
      ).thenThrow(NoSpendableUtxoException('selected coin disappeared'));
      bloc.emit(
        TransferState(
          fromWallet: _wallet(),
          toWallet: _destinationWallet(),
          receiveAddress: 'tb1qreceive',
          amount: '1000',
          selectedUtxos: [selected],
          signedPsbt: 'signed-psbt',
          feePreviewCache: const BitcoinFeePreviewCache(
            fastest: BitcoinFeePreviewSlot(
              feeSat: 250,
              unsignedPsbt: 'cached-unsigned-psbt',
              txSize: 100,
            ),
          ),
        ),
      );

      bloc.add(const TransferEvent.confirmed());
      await bloc.stream.firstWhere((state) => !state.isConfirming);

      expect(
        bloc.state.buildTransactionException?.message,
        selectedCoinsUnavailableCode,
      );
      expect(bloc.state.feePreviewCache.fastest.isCacheReady, isFalse);
      verifyNever(
        () => broadcastBitcoin.execute(any(), isPsbt: any(named: 'isPsbt')),
      );
    },
  );

  test(
    'an in-flight old amount rebuild cannot repopulate signedPsbt after amountChanged',
    () async {
      final prepareStarted = Completer<void>();
      final prepareCompleter =
          Completer<({String unsignedPsbt, int txSize, bool isToSelf})>();
      when(
        () => prepareBitcoin.execute(
          walletId: 'wallet-1',
          address: 'tb1qreceive',
          amountSat: 1000,
          networkFee: any(named: 'networkFee'),
          drain: false,
          selectedInputs: any(named: 'selectedInputs'),
          replaceByFee: true,
        ),
      ).thenAnswer((_) {
        prepareStarted.complete();
        return prepareCompleter.future;
      });
      bloc.emit(
        TransferState(
          fromWallet: _wallet(),
          toWallet: _destinationWallet(),
          receiveAddress: 'tb1qreceive',
          amount: '1000',
          bitcoinNetworkFees: _feeOptions(),
          signedPsbt: 'previous-psbt',
        ),
      );

      bloc.add(const TransferEvent.feeOptionSelected(FeeSelection.economic));
      await prepareStarted.future;
      bloc.add(const TransferEvent.amountChanged('2000'));
      prepareCompleter.complete((
        unsignedPsbt: 'old-unsigned-psbt',
        txSize: 100,
        isToSelf: true,
      ));
      await pumpEventQueue();

      expect(bloc.state.amount, '2000');
      expect(bloc.state.signedPsbt, isEmpty);
      verifyNever(
        () => signBitcoin.execute(
          walletId: 'wallet-1',
          psbt: 'old-unsigned-psbt',
        ),
      );
    },
  );

  test(
    'an in-flight swap creation cannot repopulate signedPsbt after amountChanged',
    () async {
      final prepareStarted = Completer<void>();
      final prepareCompleter =
          Completer<({String unsignedPsbt, int txSize, bool isToSelf})>();
      when(
        () => prepareBitcoin.execute(
          walletId: 'wallet-1',
          address: 'tb1qreceive',
          amountSat: 1000,
          networkFee: any(named: 'networkFee'),
          drain: false,
          selectedInputs: any(named: 'selectedInputs'),
          replaceByFee: true,
        ),
      ).thenAnswer((_) {
        prepareStarted.complete();
        return prepareCompleter.future;
      });
      when(
        () => signBitcoin.execute(
          walletId: 'wallet-1',
          psbt: 'old-unsigned-psbt',
        ),
      ).thenAnswer((_) async => (signedPsbt: 'old-signed-psbt', txSize: 100));
      when(
        () => calculateBitcoin.execute(psbt: 'old-signed-psbt'),
      ).thenAnswer((_) async => 1200);
      bloc.emit(
        TransferState(
          fromWallet: _wallet(balanceSat: BigInt.from(100000)),
          toWallet: _destinationWallet(),
          receiveAddress: 'tb1qreceive',
          amount: '1000',
          bitcoinNetworkFees: _feeOptions(),
        ),
      );

      bloc.add(const TransferEvent.swapCreated('1000'));
      await prepareStarted.future;
      bloc.add(const TransferEvent.amountChanged('2000'));
      prepareCompleter.complete((
        unsignedPsbt: 'old-unsigned-psbt',
        txSize: 100,
        isToSelf: true,
      ));
      await pumpEventQueue();

      expect(bloc.state.amount, '2000');
      expect(bloc.state.signedPsbt, isEmpty);
    },
  );

  test(
    'an in-flight swap creation cannot repopulate after destination wallet changes',
    () async {
      final prepareStarted = Completer<void>();
      final prepareCompleter =
          Completer<({String unsignedPsbt, int txSize, bool isToSelf})>();
      final destination = _destinationWallet();
      final replacementDestination = _destinationWallet(id: 'wallet-3');
      when(
        () => prepareBitcoin.execute(
          walletId: 'wallet-1',
          address: 'tb1qreceive',
          amountSat: 1000,
          networkFee: any(named: 'networkFee'),
          drain: false,
          selectedInputs: any(named: 'selectedInputs'),
          replaceByFee: true,
        ),
      ).thenAnswer((_) {
        prepareStarted.complete();
        return prepareCompleter.future;
      });
      bloc.emit(
        TransferState(
          fromWallet: _wallet(balanceSat: BigInt.from(100000)),
          toWallet: destination,
          receiveAddress: 'tb1qreceive',
          amount: '1000',
          bitcoinNetworkFees: _feeOptions(),
        ),
      );

      bloc.add(const TransferEvent.swapCreated('1000'));
      await prepareStarted.future;
      bloc.add(
        TransferEvent.walletsChanged(
          fromWallet: _wallet(balanceSat: BigInt.from(100000)),
          toWallet: replacementDestination,
        ),
      );
      prepareCompleter.complete((
        unsignedPsbt: 'old-unsigned-psbt',
        txSize: 100,
        isToSelf: true,
      ));
      await pumpEventQueue();

      expect(bloc.state.toWallet, replacementDestination);
      expect(bloc.state.signedPsbt, isEmpty);
      expect(bloc.state.isCreatingSwap, isFalse);
      expect(bloc.state.continueClicked, isFalse);
      verifyNever(
        () => signBitcoin.execute(
          walletId: 'wallet-1',
          psbt: 'old-unsigned-psbt',
        ),
      );
    },
  );

  test(
    'same selected outpoints do not invalidate in-flight swap creation',
    () async {
      final selected = _bitcoinUtxo('selected-tx');
      final prepareStarted = Completer<void>();
      final prepareCompleter =
          Completer<({String unsignedPsbt, int txSize, bool isToSelf})>();
      when(
        () => prepareBitcoin.execute(
          walletId: 'wallet-1',
          address: 'tb1qreceive',
          amountSat: 1000,
          networkFee: any(named: 'networkFee'),
          drain: false,
          selectedInputs: [selected],
          replaceByFee: true,
        ),
      ).thenAnswer((_) {
        prepareStarted.complete();
        return prepareCompleter.future;
      });
      when(
        () => signBitcoin.execute(walletId: 'wallet-1', psbt: 'unsigned-psbt'),
      ).thenAnswer((_) async => (signedPsbt: 'signed-psbt', txSize: 100));
      when(
        () => calculateBitcoin.execute(psbt: 'signed-psbt'),
      ).thenAnswer((_) async => 1200);
      bloc.emit(
        TransferState(
          fromWallet: _wallet(balanceSat: BigInt.from(100000)),
          toWallet: _destinationWallet(),
          receiveAddress: 'tb1qreceive',
          amount: '1000',
          selectedUtxos: [selected],
          bitcoinNetworkFees: _feeOptions(),
        ),
      );

      bloc.add(const TransferEvent.swapCreated('1000'));
      await prepareStarted.future;
      bloc.add(TransferEvent.utxosSelected([selected]));
      prepareCompleter.complete((
        unsignedPsbt: 'unsigned-psbt',
        txSize: 100,
        isToSelf: true,
      ));
      await bloc.stream.firstWhere(
        (state) => state.signedPsbt == 'signed-psbt',
      );

      expect(bloc.state.isCreatingSwap, isFalse);
      expect(bloc.state.signedPsbt, 'signed-psbt');
    },
  );

  test('send-to-external changes invalidate transaction work', () async {
    bloc.emit(
      TransferState(
        signedPsbt: 'stale-psbt',
        isCreatingSwap: true,
        continueClicked: true,
        receiveExactAmount: false,
      ),
    );

    bloc.add(const TransferEvent.sendToExternalToggled(true));
    await pumpEventQueue();

    expect(bloc.state.sendToExternal, isTrue);
    expect(bloc.state.receiveExactAmount, isTrue);
    expect(bloc.state.signedPsbt, isEmpty);
    expect(bloc.state.isCreatingSwap, isFalse);
    expect(bloc.state.continueClicked, isFalse);
  });

  test('receive-exact-amount changes invalidate transaction work', () async {
    bloc.emit(
      TransferState(
        signedPsbt: 'stale-psbt',
        isCreatingSwap: true,
        continueClicked: true,
        receiveExactAmount: false,
      ),
    );

    bloc.add(const TransferEvent.receiveExactAmountToggled(true));
    await pumpEventQueue();

    expect(bloc.state.receiveExactAmount, isTrue);
    expect(bloc.state.signedPsbt, isEmpty);
    expect(bloc.state.isCreatingSwap, isFalse);
    expect(bloc.state.continueClicked, isFalse);
  });

  test(
    'contract changes detach a prepared swap before an RBF rebuild',
    () async {
      when(
        () => prepareBitcoin.execute(
          walletId: 'wallet-1',
          address: 'payin-address',
          amountSat: 1000,
          networkFee: any(named: 'networkFee'),
          drain: false,
          selectedInputs: any(named: 'selectedInputs'),
          replaceByFee: false,
        ),
      ).thenAnswer(
        (_) async =>
            (unsignedPsbt: 'new-unsigned-psbt', txSize: 100, isToSelf: false),
      );
      when(
        () => verifyChain.execute(
          psbtOrPset: 'new-unsigned-psbt',
          swap: _swap(),
          walletId: 'wallet-1',
        ),
      ).thenAnswer((_) async {});
      when(
        () => signBitcoin.execute(
          walletId: 'wallet-1',
          psbt: 'new-unsigned-psbt',
        ),
      ).thenAnswer((_) async => (signedPsbt: 'new-signed-psbt', txSize: 100));
      when(
        () => calculateBitcoin.execute(psbt: 'new-signed-psbt'),
      ).thenAnswer((_) async => 1200);
      when(
        () => replacePrepared.execute(
          localId: 'local-1',
          signedTransaction: 'new-signed-psbt',
          isPsbt: true,
        ),
      ).thenAnswer((_) async => Ok(prepared));
      bloc.emit(
        TransferState(
          fromWallet: _wallet(balanceSat: BigInt.from(100000)),
          toWallet: _liquidWallet(id: 'wallet-2'),
          swap: _swap(),
          orderSwap: prepared,
          amount: '1000',
          bitcoinNetworkFees: _feeOptions(),
          signedPsbt: 'old-signed-psbt',
        ),
      );

      bloc.add(const TransferEvent.amountChanged('2000'));
      await pumpEventQueue();

      bloc.add(const TransferEvent.replaceByFeeChanged(false));
      await pumpEventQueue();

      verifyNever(
        () => replacePrepared.execute(
          localId: 'local-1',
          signedTransaction: 'new-signed-psbt',
          isPsbt: true,
        ),
      );
      expect(bloc.state.swap, isNull);
      expect(bloc.state.orderSwap, isNull);
    },
  );

  test('RBF rebuild preserves an unchanged prepared swap context', () async {
    when(
      () => prepareBitcoin.execute(
        walletId: 'wallet-1',
        address: 'payin-address',
        amountSat: 1000,
        networkFee: any(named: 'networkFee'),
        drain: false,
        selectedInputs: any(named: 'selectedInputs'),
        replaceByFee: false,
      ),
    ).thenAnswer(
      (_) async =>
          (unsignedPsbt: 'new-unsigned-psbt', txSize: 100, isToSelf: false),
    );
    when(
      () => verifyChain.execute(
        psbtOrPset: 'new-unsigned-psbt',
        swap: _swap(),
        walletId: 'wallet-1',
      ),
    ).thenAnswer((_) async {});
    when(
      () =>
          signBitcoin.execute(walletId: 'wallet-1', psbt: 'new-unsigned-psbt'),
    ).thenAnswer((_) async => (signedPsbt: 'new-signed-psbt', txSize: 100));
    when(
      () => calculateBitcoin.execute(psbt: 'new-signed-psbt'),
    ).thenAnswer((_) async => 1200);
    when(
      () => replacePrepared.execute(
        localId: 'local-1',
        signedTransaction: 'new-signed-psbt',
        isPsbt: true,
      ),
    ).thenAnswer((_) async => Ok(prepared));
    bloc.emit(
      TransferState(
        fromWallet: _wallet(balanceSat: BigInt.from(100000)),
        toWallet: _liquidWallet(id: 'wallet-2'),
        swap: _swap(),
        orderSwap: prepared,
        amount: '1000',
        bitcoinNetworkFees: _feeOptions(),
        signedPsbt: 'old-signed-psbt',
      ),
    );

    bloc.add(const TransferEvent.replaceByFeeChanged(false));
    await pumpEventQueue();

    verify(
      () => replacePrepared.execute(
        localId: 'local-1',
        signedTransaction: 'new-signed-psbt',
        isPsbt: true,
      ),
    ).called(1);
    expect(bloc.state.orderSwap, prepared);
  });

  test('emits the transaction id before wallet sync completes', () async {
    final syncCompleter = Completer<Wallet>();
    final broadcasting = _prepared(
      status: OrderSwapLocalStatus.broadcastUnknown,
    );
    final broadcasted = _prepared(
      status: OrderSwapLocalStatus.payinBroadcast,
      transactionId: 'txid-1',
    );
    when(
      () => getWallet.execute('wallet-1', sync: true),
    ).thenAnswer((_) => syncCompleter.future);
    when(
      () => markUnknown.execute('local-1'),
    ).thenAnswer((_) async => Ok(broadcasting));
    when(
      () => broadcastBitcoin.execute('signed-psbt', isPsbt: true),
    ).thenAnswer((_) async => 'txid-1');
    when(
      () => markBroadcast.execute(localId: 'local-1', transactionId: 'txid-1'),
    ).thenAnswer((_) async => Ok(broadcasted));
    bloc.emit(
      TransferState(
        orderSwap: prepared,
        signedPsbt: 'signed-psbt',
        fromWallet: _wallet(),
        swap: _swap(),
      ),
    );

    bloc.add(const TransferEvent.confirmed());
    await bloc.stream.firstWhere((state) => state.txId == 'txid-1');

    expect(syncCompleter.isCompleted, isFalse);
    expect(bloc.state.orderSwap, broadcasted);
    syncCompleter.complete(_wallet());
  });

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

Wallet _wallet({BigInt? balanceSat}) => Wallet(
  origin: 'wallet-1',
  network: Network.bitcoinTestnet,
  signers: [
    WalletSigner.single(
      masterFingerprint: 'fingerprint',
      xpubFingerprint: 'fingerprint',
      xpub: 'xpub',
      derivationPath: "m/84'/1'/0'",
      descriptorPath: standardSingleSignatureDescriptorPath,
      signer: SignerEntity.local,
      signerDevice: null,
    ),
  ],
  scriptType: ScriptType.bip84,
  publicDescriptor: 'external',
  balanceSat: balanceSat ?? BigInt.zero,
);

WalletUtxo _bitcoinUtxo(String txId) => WalletUtxo.bitcoin(
  walletId: 'wallet-1',
  txId: txId,
  vout: 0,
  scriptPubkey: Uint8List.fromList([0]),
  amountSat: BigInt.from(2000),
  address: 'tb1qsource',
);

Wallet _liquidWallet({String id = 'wallet-1', bool isDefault = false}) =>
    Wallet(
      origin: id,
      network: Network.liquidTestnet,
      signers: [
        WalletSigner.single(
          masterFingerprint: 'fingerprint-1',
          xpubFingerprint: 'fingerprint-1',
          xpub: 'xpub-1',
          signer: SignerEntity.local,
          signerDevice: null,
        ),
      ],
      scriptType: ScriptType.bip84,
      publicDescriptor: 'external-1',
      isDefault: isDefault,
      balanceSat: BigInt.zero,
    );

Wallet _destinationWallet({String id = 'wallet-2', bool isDefault = false}) =>
    Wallet(
      origin: id,
      network: Network.bitcoinTestnet,
      signers: [
        WalletSigner.single(
          masterFingerprint: 'fingerprint-2',
          xpubFingerprint: 'fingerprint-2',
          xpub: 'xpub-2',
          derivationPath: "m/84'/1'/0'",
          descriptorPath: standardSingleSignatureDescriptorPath,
          signer: SignerEntity.local,
          signerDevice: null,
        ),
      ],
      scriptType: ScriptType.bip84,
      publicDescriptor: 'external-2',
      isDefault: isDefault,
      balanceSat: BigInt.from(2000),
    );

FeeOptions _feeOptions() => const FeeOptions(
  fastest: RelativeFee(250),
  economic: RelativeFee(250),
  slow: RelativeFee(250),
  minRelay: RelativeFee(25),
);
