import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/create_chain_swap_to_external_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/decode_invoice_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/update_send_swap_lockup_fees_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_pset_size_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_presets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/select_best_wallet_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/try_liquid_direct_pay_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/update_paid_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockLabelsFacade extends Mock implements LabelsFacade {}

class _MockSelectBestWalletUsecase extends Mock
    implements SelectBestWalletUsecase {}

class _MockDetectBitcoinStringUsecase extends Mock
    implements DetectBitcoinStringUsecase {}

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockConvertSatsToCurrencyAmountUsecase extends Mock
    implements ConvertSatsToCurrencyAmountUsecase {}

class _MockGetNetworkFeesUsecase extends Mock
    implements GetNetworkFeesUsecase {}

class _MockGetWalletUtxosUsecase extends Mock
    implements GetWalletUtxosUsecase {}

class _MockGetAvailableCurrenciesUsecase extends Mock
    implements GetAvailableCurrenciesUsecase {}

class _MockPrepareBitcoinSendUsecase extends Mock
    implements PrepareBitcoinSendUsecase {}

class _MockPrepareLiquidSendUsecase extends Mock
    implements PrepareLiquidSendUsecase {}

class _MockSendWithPayjoinUsecase extends Mock
    implements SendWithPayjoinUsecase {}

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class _MockCreateSendSwapUsecase extends Mock
    implements CreateSendSwapUsecase {}

class _MockUpdatePaidSendSwapUsecase extends Mock
    implements UpdatePaidSendSwapUsecase {}

class _MockGetSwapLimitsUsecase extends Mock implements GetSwapLimitsUsecase {}

class _MockWatchSwapUsecase extends Mock implements WatchSwapUsecase {}

class _MockWatchFinishedWalletSyncsUsecase extends Mock
    implements WatchFinishedWalletSyncsUsecase {}

class _MockDecodeInvoiceUsecase extends Mock implements DecodeInvoiceUsecase {}

class _MockSignBitcoinTxUsecase extends Mock implements SignBitcoinTxUsecase {}

class _MockSignLiquidTxUsecase extends Mock implements SignLiquidTxUsecase {}

class _MockBroadcastBitcoinTransactionUsecase extends Mock
    implements BroadcastBitcoinTransactionUsecase {}

class _MockBroadcastLiquidTransactionUsecase extends Mock
    implements BroadcastLiquidTransactionUsecase {}

class _MockCalculateLiquidAbsoluteFeesUsecase extends Mock
    implements CalculateLiquidAbsoluteFeesUsecase {}

class _MockCreateChainSwapToExternalUsecase extends Mock
    implements CreateChainSwapToExternalUsecase {}

class _MockWatchWalletTransactionByTxIdUsecase extends Mock
    implements WatchWalletTransactionByTxIdUsecase {}

class _MockCalculateBitcoinAbsoluteFeesUsecase extends Mock
    implements CalculateBitcoinAbsoluteFeesUsecase {}

class _MockUpdateSendSwapLockupFeesUsecase extends Mock
    implements UpdateSendSwapLockupFeesUsecase {}

class _MockVerifyChainSwapAmountSendUsecase extends Mock
    implements VerifyChainSwapAmountSendUsecase {}

class _MockTryLiquidDirectPayUsecase extends Mock
    implements TryLiquidDirectPayUsecase {}

class _MockPreviewBitcoinFeeUsecase extends Mock
    implements PreviewBitcoinFeeUsecase {}

class _MockPreviewBitcoinFeePresetsUsecase extends Mock
    implements PreviewBitcoinFeePresetsUsecase {}

class _MockCalculateLiquidPsetSizeUsecase extends Mock
    implements CalculateLiquidPsetSizeUsecase {}

void registerSendCubitHarnessFallbacks() {
  registerFallbackValue(SwapType.liquidToLightning);
  registerFallbackValue(const NetworkFee.absolute(1));
  registerFallbackValue(NetworkFee.relativeFromSatPerVbyte(1));
  registerFallbackValue(
    const PaymentRequest.liquid(address: 'lq1fallback', isTestnet: false),
  );
}

class SendCubitHarness {
  final LabelsFacade _labels = _MockLabelsFacade();
  final SelectBestWalletUsecase _bestWallet = _MockSelectBestWalletUsecase();
  final DetectBitcoinStringUsecase _detectBitcoinString =
      _MockDetectBitcoinStringUsecase();
  final GetSettingsUsecase _getSettings = _MockGetSettingsUsecase();
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrency =
      _MockConvertSatsToCurrencyAmountUsecase();
  final GetNetworkFeesUsecase getNetworkFees = _MockGetNetworkFeesUsecase();
  final GetWalletUtxosUsecase getWalletUtxos = _MockGetWalletUtxosUsecase();
  final GetAvailableCurrenciesUsecase _getAvailableCurrencies =
      _MockGetAvailableCurrenciesUsecase();
  final PrepareBitcoinSendUsecase _prepareBitcoinSend =
      _MockPrepareBitcoinSendUsecase();
  final PrepareLiquidSendUsecase prepareLiquidSend =
      _MockPrepareLiquidSendUsecase();
  final SendWithPayjoinUsecase _sendWithPayjoin = _MockSendWithPayjoinUsecase();
  final GetWalletsUsecase _getWallets = _MockGetWalletsUsecase();
  final GetWalletUsecase _getWallet = _MockGetWalletUsecase();
  final CreateSendSwapUsecase createSendSwap = _MockCreateSendSwapUsecase();
  final UpdatePaidSendSwapUsecase _updatePaidSendSwap =
      _MockUpdatePaidSendSwapUsecase();
  final GetSwapLimitsUsecase getSwapLimits = _MockGetSwapLimitsUsecase();
  final WatchSwapUsecase _watchSwap = _MockWatchSwapUsecase();
  final WatchFinishedWalletSyncsUsecase _watchFinishedWalletSyncs =
      _MockWatchFinishedWalletSyncsUsecase();
  final DecodeInvoiceUsecase _decodeInvoice = _MockDecodeInvoiceUsecase();
  final SignBitcoinTxUsecase _signBitcoinTx = _MockSignBitcoinTxUsecase();
  final SignLiquidTxUsecase _signLiquidTx = _MockSignLiquidTxUsecase();
  final BroadcastBitcoinTransactionUsecase _broadcastBitcoinTx =
      _MockBroadcastBitcoinTransactionUsecase();
  final BroadcastLiquidTransactionUsecase _broadcastLiquidTx =
      _MockBroadcastLiquidTransactionUsecase();
  final CalculateLiquidAbsoluteFeesUsecase calculateLiquidAbsoluteFees =
      _MockCalculateLiquidAbsoluteFeesUsecase();
  final CreateChainSwapToExternalUsecase _createChainSwapToExternal =
      _MockCreateChainSwapToExternalUsecase();
  final WatchWalletTransactionByTxIdUsecase _watchWalletTransactionByTxId =
      _MockWatchWalletTransactionByTxIdUsecase();
  final CalculateBitcoinAbsoluteFeesUsecase _calculateBitcoinAbsoluteFees =
      _MockCalculateBitcoinAbsoluteFeesUsecase();
  final UpdateSendSwapLockupFeesUsecase updateSendSwapLockupFees =
      _MockUpdateSendSwapLockupFeesUsecase();
  final VerifyChainSwapAmountSendUsecase _verifyChainSwapAmountSend =
      _MockVerifyChainSwapAmountSendUsecase();
  final TryLiquidDirectPayUsecase tryLiquidDirectPay =
      _MockTryLiquidDirectPayUsecase();
  final PreviewBitcoinFeeUsecase previewBitcoinFee =
      _MockPreviewBitcoinFeeUsecase();
  final PreviewBitcoinFeePresetsUsecase previewBitcoinFeePresets =
      _MockPreviewBitcoinFeePresetsUsecase();
  final CalculateLiquidPsetSizeUsecase calculateLiquidPsetSize =
      _MockCalculateLiquidPsetSizeUsecase();

  SendCubitHarness() {
    when(() => _getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    when(() => _convertSatsToCurrency.execute()).thenAnswer((_) async => 1);
    when(
      () => _convertSatsToCurrency.execute(
        currencyCode: any(named: 'currencyCode'),
      ),
    ).thenAnswer((_) async => 1);
    when(
      () => _getAvailableCurrencies.execute(),
    ).thenAnswer((_) async => ['USD']);
    when(
      () => _watchSwap.execute(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => getNetworkFees.execute(isLiquid: any(named: 'isLiquid')),
    ).thenAnswer((_) async => sendCubitFeeOptions());
    when(
      () => getWalletUtxos.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => []);
    when(
      () => _watchWalletTransactionByTxId.execute(
        walletId: any(named: 'walletId'),
        txId: any(named: 'txId'),
      ),
    ).thenAnswer((_) => const Stream.empty());
  }

  SendCubit createCubit({Wallet? wallet}) {
    return SendCubit(
      wallet: wallet,
      labelsFacade: _labels,
      bestWalletUsecase: _bestWallet,
      detectBitcoinStringUsecase: _detectBitcoinString,
      getSettingsUsecase: _getSettings,
      convertSatsToCurrencyAmountUsecase: _convertSatsToCurrency,
      getNetworkFeesUsecase: getNetworkFees,
      getWalletUtxosUsecase: getWalletUtxos,
      getAvailableCurrenciesUsecase: _getAvailableCurrencies,
      prepareBitcoinSendUsecase: _prepareBitcoinSend,
      prepareLiquidSendUsecase: prepareLiquidSend,
      sendWithPayjoinUsecase: _sendWithPayjoin,
      getWalletsUsecase: _getWallets,
      getWalletUsecase: _getWallet,
      createSendSwapUsecase: createSendSwap,
      updatePaidSendSwapUsecase: _updatePaidSendSwap,
      getSwapLimitsUsecase: getSwapLimits,
      watchSwapUsecase: _watchSwap,
      watchFinishedWalletSyncsUsecase: _watchFinishedWalletSyncs,
      decodeInvoiceUsecase: _decodeInvoice,
      signBitcoinTxUsecase: _signBitcoinTx,
      signLiquidTxUsecase: _signLiquidTx,
      broadcastBitcoinTxUsecase: _broadcastBitcoinTx,
      broadcastLiquidTxUsecase: _broadcastLiquidTx,
      calculateLiquidAbsoluteFeesUsecase: calculateLiquidAbsoluteFees,
      createChainSwapToExternalUsecase: _createChainSwapToExternal,
      watchWalletTransactionByTxIdUsecase: _watchWalletTransactionByTxId,
      calculateBitcoinAbsoluteFeesUsecase: _calculateBitcoinAbsoluteFees,
      updateSendSwapLockupFeesUsecase: updateSendSwapLockupFees,
      verifyChainSwapAmountSendUsecase: _verifyChainSwapAmountSend,
      tryLiquidDirectPayUsecase: tryLiquidDirectPay,
      calculateLiquidPsetSizeUsecase: calculateLiquidPsetSize,
      previewBitcoinFeeUsecase: previewBitcoinFee,
      previewBitcoinFeePresetsUsecase: previewBitcoinFeePresets,
    );
  }

  void seed(SendCubit cubit, SendState state) {
    (cubit as dynamic).emit(state);
  }
}

Wallet sendCubitWallet({
  required String id,
  required String label,
  Network network = Network.liquidMainnet,
  BigInt? balanceSat,
}) {
  return Wallet(
    origin: id,
    label: label,
    network: network,
    xpubFingerprint: '',
    scriptType: ScriptType.bip84,
    xpub: '',
    externalPublicDescriptor: '',
    internalPublicDescriptor: '',
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: balanceSat ?? BigInt.zero,
  );
}

LnSendSwap sendCubitLnSendSwap({
  String id = 'swap-id',
  String walletId = 'wallet-id',
  String paymentAddress = 'lq1swap',
  int paymentAmount = 1000,
}) {
  return Swap.lnSend(
        id: id,
        keyIndex: 0,
        type: SwapType.liquidToLightning,
        status: SwapStatus.pending,
        environment: Environment.mainnet,
        creationTime: DateTime.utc(2026),
        sendWalletId: walletId,
        invoice: 'lnbc1000n1test',
        paymentAddress: paymentAddress,
        paymentAmount: paymentAmount,
      )
      as LnSendSwap;
}

FeeOptions sendCubitFeeOptions() {
  return FeeOptions(
    fastest: const NetworkFee.absolute(1),
    economic: const NetworkFee.absolute(1),
    slow: const NetworkFee.absolute(1),
    minRelay: NetworkFee.relativeFromSatPerVbyte(0.1),
  );
}
