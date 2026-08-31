import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/insufficient_funds_exception.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/validate_bitcoin_selection_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_pset_size_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_send_cross_chain_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_cross_chain_quote_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_swap_quote_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_presets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/resolve_lightning_address_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/select_best_wallet_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/update_paid_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/verify_signed_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/verify_exchange_payin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/update_send_swap_payin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_send_swap_usecase.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Sats;

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

class _MockValidateBitcoinSelectionUsecase extends Mock
    implements ValidateBitcoinSelectionUsecase {}

class _MockPrepareLiquidSendUsecase extends Mock
    implements PrepareLiquidSendUsecase {}

class _MockSendWithPayjoinUsecase extends Mock
    implements SendWithPayjoinUsecase {}

class _MockWatchPayjoinUsecase extends Mock implements WatchPayjoinUsecase {}

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class _MockCreateSendSwapUsecase extends Mock
    implements CreateSendSwapUsecase {}

class _MockGetSendSwapQuoteUsecase extends Mock
    implements GetSendSwapQuoteUsecase {}

class _MockCreateSendCrossChainSwapUsecase extends Mock
    implements CreateSendCrossChainSwapUsecase {}

class _MockGetSendCrossChainQuoteUsecase extends Mock
    implements GetSendCrossChainQuoteUsecase {}

class _MockResolveLightningAddressUsecase extends Mock
    implements ResolveLightningAddressUsecase {}

class _MockUpdateSendSwapPayinUsecase extends Mock
    implements UpdateSendSwapPayinUsecase {}

class _MockWatchSendSwapUsecase extends Mock implements WatchSendSwapUsecase {}

class _MockUpdatePaidSendSwapUsecase extends Mock
    implements UpdatePaidSendSwapUsecase {}

class _MockWatchFinishedWalletSyncsUsecase extends Mock
    implements WatchFinishedWalletSyncsUsecase {}

class _MockSignBitcoinTxUsecase extends Mock implements SignBitcoinTxUsecase {}

class _MockSignLiquidTxUsecase extends Mock implements SignLiquidTxUsecase {}

class _MockBroadcastBitcoinTransactionUsecase extends Mock
    implements BroadcastBitcoinTransactionUsecase {}

class _MockBroadcastLiquidTransactionUsecase extends Mock
    implements BroadcastLiquidTransactionUsecase {}

class _MockCalculateLiquidAbsoluteFeesUsecase extends Mock
    implements CalculateLiquidAbsoluteFeesUsecase {}

class _MockCalculateLiquidPsetSizeUsecase extends Mock
    implements CalculateLiquidPsetSizeUsecase {}

class _MockWatchWalletTransactionByTxIdUsecase extends Mock
    implements WatchWalletTransactionByTxIdUsecase {}

class _MockCalculateBitcoinAbsoluteFeesUsecase extends Mock
    implements CalculateBitcoinAbsoluteFeesUsecase {}

class _MockVerifyChainSwapAmountSendUsecase extends Mock
    implements VerifyChainSwapAmountSendUsecase {}

class _MockVerifyExchangePayinUsecase extends Mock
    implements VerifyExchangePayinUsecase {}

class _MockPreviewBitcoinFeeUsecase extends Mock
    implements PreviewBitcoinFeeUsecase {}

class _MockPreviewBitcoinFeePresetsUsecase extends Mock
    implements PreviewBitcoinFeePresetsUsecase {}

class _MockCheckLiquidConsolidationUsecase extends Mock
    implements CheckLiquidConsolidationUsecase {}

class _MockGetSendPayjoinEnabledUsecase extends Mock
    implements GetSendPayjoinEnabledUsecase {}

class _MockVerifySignedTxUsecase extends Mock
    implements VerifySignedTxUsecase {}

class _FakeNewLabel extends Fake implements NewLabel {}

/// Test seam: [SendCubit]'s payjoin watcher ([_watchPayjoin]) is private and
/// only started from the tail of the public [SendCubit.signTransaction]. This
/// subclass exposes [emit] so a test can stage exactly the precondition state
/// that drives `signTransaction` into its payjoin branch — nothing about the
/// production class is changed; the tests exercise the real
/// `signTransaction` → `_watchPayjoin` code path.
class _TestableSendCubit extends SendCubit {
  _TestableSendCubit({
    required super.labelsFacade,
    required super.bestWalletUsecase,
    required super.detectBitcoinStringUsecase,
    required super.getSettingsUsecase,
    required super.convertSatsToCurrencyAmountUsecase,
    required super.getNetworkFeesUsecase,
    required super.getWalletUtxosUsecase,
    required super.getAvailableCurrenciesUsecase,
    required super.prepareBitcoinSendUsecase,
    required super.validateBitcoinSelectionUsecase,
    required super.prepareLiquidSendUsecase,
    required super.sendWithPayjoinUsecase,
    required super.watchPayjoinUsecase,
    required super.getWalletsUsecase,
    required super.getWalletUsecase,
    required super.createSendSwapUsecase,
    required super.getSendSwapQuoteUsecase,
    required super.createSendCrossChainSwapUsecase,
    required super.getSendCrossChainQuoteUsecase,
    required super.resolveLightningAddressUsecase,
    required super.updateSendSwapPayinUsecase,
    required super.watchSendSwapUsecase,
    required super.updatePaidSendSwapUsecase,
    required super.watchFinishedWalletSyncsUsecase,
    required super.signBitcoinTxUsecase,
    required super.signLiquidTxUsecase,
    required super.broadcastBitcoinTxUsecase,
    required super.broadcastLiquidTxUsecase,
    required super.calculateLiquidAbsoluteFeesUsecase,
    required super.calculateLiquidPsetSizeUsecase,
    required super.watchWalletTransactionByTxIdUsecase,
    required super.calculateBitcoinAbsoluteFeesUsecase,
    required super.verifyChainSwapAmountSendUsecase,
    required super.verifyExchangePayinUsecase,
    required super.previewBitcoinFeeUsecase,
    required super.previewBitcoinFeePresetsUsecase,
    required super.checkLiquidConsolidationUsecase,
    required super.getSendPayjoinEnabledUsecase,
    required super.verifySignedTxUsecase,
    super.parsePaymentRequest,
  });

  void setStateForTest(SendState state) => emit(state);
}

Wallet _bitcoinLocalWallet() => Wallet(
  origin: 'w1',
  network: Network.bitcoinMainnet,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(1000000),
);

Wallet _liquidWallet({required int balanceSat}) => Wallet(
  origin: 'w-liquid',
  network: Network.liquidMainnet,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(balanceSat),
);

Wallet _bitcoinWallet({required int balanceSat}) => Wallet(
  origin: 'w-bitcoin',
  network: Network.bitcoinMainnet,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(balanceSat),
);

WalletUtxo _utxo({
  required int amountSat,
  int vout = 0,
  bool isFrozen = false,
}) => WalletUtxo.bitcoin(
  walletId: 'w-bitcoin',
  txId: 'a' * 64,
  vout: vout,
  scriptPubkey: Uint8List(0),
  amountSat: BigInt.from(amountSat),
  address: 'bc1-utxo',
  isFrozen: isFrozen,
);

FeeOptions _feeOptions() => const FeeOptions(
  fastest: RelativeFee(25),
  economic: RelativeFee(25),
  slow: RelativeFee(25),
  minRelay: RelativeFee(25),
);

Bip21PaymentRequest _payjoinBip21() =>
    const PaymentRequest.bip21(
          network: Network.bitcoinMainnet,
          uri: 'bitcoin:bc1qaddr?amount=0.0005&pj=https://payjo.in',
          address: 'bc1qaddr',
          amountSat: 50000,
          pj: 'https://payjo.in',
        )
        as Bip21PaymentRequest;

PayjoinSenderSession _sender({
  required PayjoinStatus status,
  String? txId,
  String originalTxId = 'sender-orig-txid',
}) => PayjoinSenderSession(
  status: status,
  uri: 'bitcoin:bc1qaddr?amount=0.0005&pj=https://payjo.in',
  network: BitcoinNetwork.mainnet,
  walletId: 'w1',
  originalTransactionId: originalTxId,
  amount: Sats.fromInt(50000),
  createdAt: DateTime(2026),
  expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
  transactionId: txId,
);

void main() {
  late _MockLabelsFacade labelsFacade;
  late _MockSelectBestWalletUsecase bestWalletUsecase;
  late _MockDetectBitcoinStringUsecase detectBitcoinStringUsecase;
  late _MockGetSettingsUsecase getSettingsUsecase;
  late _MockConvertSatsToCurrencyAmountUsecase convertSatsUsecase;
  late _MockGetNetworkFeesUsecase getNetworkFeesUsecase;
  late _MockGetWalletUtxosUsecase getWalletUtxosUsecase;
  late _MockGetAvailableCurrenciesUsecase getAvailableCurrenciesUsecase;
  late _MockPrepareBitcoinSendUsecase prepareBitcoinSendUsecase;
  late _MockValidateBitcoinSelectionUsecase validateBitcoinSelectionUsecase;
  late _MockPrepareLiquidSendUsecase prepareLiquidSendUsecase;
  late _MockSendWithPayjoinUsecase sendWithPayjoinUsecase;
  late _MockWatchPayjoinUsecase watchPayjoinUsecase;
  late _MockGetWalletsUsecase getWalletsUsecase;
  late _MockGetWalletUsecase getWalletUsecase;
  late _MockCreateSendSwapUsecase createSendSwapUsecase;
  late _MockGetSendSwapQuoteUsecase getSendSwapQuoteUsecase;
  late _MockCreateSendCrossChainSwapUsecase createSendCrossChainSwapUsecase;
  late _MockGetSendCrossChainQuoteUsecase getSendCrossChainQuoteUsecase;
  late _MockResolveLightningAddressUsecase resolveLightningAddressUsecase;
  late _MockUpdateSendSwapPayinUsecase updateSendSwapPayinUsecase;
  late _MockWatchSendSwapUsecase watchSendSwapUsecase;
  late _MockUpdatePaidSendSwapUsecase updatePaidSendSwapUsecase;
  late _MockWatchFinishedWalletSyncsUsecase watchFinishedWalletSyncsUsecase;
  late _MockSignBitcoinTxUsecase signBitcoinTxUsecase;
  late _MockSignLiquidTxUsecase signLiquidTxUsecase;
  late _MockBroadcastBitcoinTransactionUsecase broadcastBitcoinTxUsecase;
  late _MockBroadcastLiquidTransactionUsecase broadcastLiquidTxUsecase;
  late _MockCalculateLiquidAbsoluteFeesUsecase
  calculateLiquidAbsoluteFeesUsecase;
  late _MockCalculateLiquidPsetSizeUsecase calculateLiquidPsetSizeUsecase;
  late _MockWatchWalletTransactionByTxIdUsecase
  watchWalletTransactionByTxIdUsecase;
  late _MockCalculateBitcoinAbsoluteFeesUsecase
  calculateBitcoinAbsoluteFeesUsecase;
  late _MockVerifyChainSwapAmountSendUsecase verifyChainSwapAmountSendUsecase;
  late _MockVerifyExchangePayinUsecase verifyExchangePayinUsecase;
  late _MockPreviewBitcoinFeeUsecase previewBitcoinFeeUsecase;
  late _MockPreviewBitcoinFeePresetsUsecase previewBitcoinFeePresetsUsecase;
  late _MockCheckLiquidConsolidationUsecase checkLiquidConsolidationUsecase;
  late _MockVerifySignedTxUsecase verifySignedTxUsecase;

  late StreamController<PayjoinSession> payjoinEvents;

  _TestableSendCubit buildCubit({
    Future<PaymentRequest> Function(String)? parsePaymentRequest,
  }) => _TestableSendCubit(
    labelsFacade: labelsFacade,
    bestWalletUsecase: bestWalletUsecase,
    detectBitcoinStringUsecase: detectBitcoinStringUsecase,
    getSettingsUsecase: getSettingsUsecase,
    convertSatsToCurrencyAmountUsecase: convertSatsUsecase,
    getNetworkFeesUsecase: getNetworkFeesUsecase,
    getWalletUtxosUsecase: getWalletUtxosUsecase,
    getAvailableCurrenciesUsecase: getAvailableCurrenciesUsecase,
    prepareBitcoinSendUsecase: prepareBitcoinSendUsecase,
    validateBitcoinSelectionUsecase: validateBitcoinSelectionUsecase,
    prepareLiquidSendUsecase: prepareLiquidSendUsecase,
    sendWithPayjoinUsecase: sendWithPayjoinUsecase,
    watchPayjoinUsecase: watchPayjoinUsecase,
    getWalletsUsecase: getWalletsUsecase,
    getWalletUsecase: getWalletUsecase,
    createSendSwapUsecase: createSendSwapUsecase,
    getSendSwapQuoteUsecase: getSendSwapQuoteUsecase,
    createSendCrossChainSwapUsecase: createSendCrossChainSwapUsecase,
    getSendCrossChainQuoteUsecase: getSendCrossChainQuoteUsecase,
    resolveLightningAddressUsecase: resolveLightningAddressUsecase,
    updateSendSwapPayinUsecase: updateSendSwapPayinUsecase,
    watchSendSwapUsecase: watchSendSwapUsecase,
    updatePaidSendSwapUsecase: updatePaidSendSwapUsecase,
    watchFinishedWalletSyncsUsecase: watchFinishedWalletSyncsUsecase,
    signBitcoinTxUsecase: signBitcoinTxUsecase,
    signLiquidTxUsecase: signLiquidTxUsecase,
    broadcastBitcoinTxUsecase: broadcastBitcoinTxUsecase,
    broadcastLiquidTxUsecase: broadcastLiquidTxUsecase,
    calculateLiquidAbsoluteFeesUsecase: calculateLiquidAbsoluteFeesUsecase,
    calculateLiquidPsetSizeUsecase: calculateLiquidPsetSizeUsecase,
    watchWalletTransactionByTxIdUsecase: watchWalletTransactionByTxIdUsecase,
    calculateBitcoinAbsoluteFeesUsecase: calculateBitcoinAbsoluteFeesUsecase,
    verifyChainSwapAmountSendUsecase: verifyChainSwapAmountSendUsecase,
    verifyExchangePayinUsecase: verifyExchangePayinUsecase,
    previewBitcoinFeeUsecase: previewBitcoinFeeUsecase,
    previewBitcoinFeePresetsUsecase: previewBitcoinFeePresetsUsecase,
    checkLiquidConsolidationUsecase: checkLiquidConsolidationUsecase,
    getSendPayjoinEnabledUsecase: _MockGetSendPayjoinEnabledUsecase(),
    verifySignedTxUsecase: verifySignedTxUsecase,
    parsePaymentRequest: parsePaymentRequest,
  );

  /// Precondition state that makes [SendState.willAttemptPayjoin] true and
  /// gives `signTransaction` everything its bitcoin payjoin branch reads:
  /// a local-signing bitcoin wallet, a BIP21 request carrying a `pj`
  /// endpoint, payjoin enabled, not a self-send, an unsigned PSBT, a
  /// confirmed amount and a relative fee. [label] is the user's typed note.
  SendState payjoinReadyState({String label = ''}) => SendState(
    step: SendStep.confirm,
    sendType: SendType.bitcoin,
    selectedWallet: _bitcoinLocalWallet(),
    paymentRequest: _payjoinBip21(),
    payjoinGloballyEnabled: true,
    isToSelf: false,
    unsignedPsbt: 'cHNidP8=',
    confirmedAmountSat: 50000,
    label: label,
    selectedFeeOption: FeeSelection.custom,
    customFee: NetworkFee.relativeFromSatPerVbyte(2),
  );

  setUpAll(() {
    registerFallbackValue(_FakeNewLabel());
    registerFallbackValue(_bitcoinLocalWallet());
    registerFallbackValue(BigInt.zero);
    registerFallbackValue(
      const PaymentRequest.bitcoin(address: 'fallback', isTestnet: true),
    );
    // For any(named: 'feeRate') on the prepare-send stubs.
    registerFallbackValue(NetworkFee.relativeFromSatPerVbyte(1));
  });

  setUp(() {
    labelsFacade = _MockLabelsFacade();
    bestWalletUsecase = _MockSelectBestWalletUsecase();
    detectBitcoinStringUsecase = _MockDetectBitcoinStringUsecase();
    getSettingsUsecase = _MockGetSettingsUsecase();
    convertSatsUsecase = _MockConvertSatsToCurrencyAmountUsecase();
    getNetworkFeesUsecase = _MockGetNetworkFeesUsecase();
    getWalletUtxosUsecase = _MockGetWalletUtxosUsecase();
    getAvailableCurrenciesUsecase = _MockGetAvailableCurrenciesUsecase();
    prepareBitcoinSendUsecase = _MockPrepareBitcoinSendUsecase();
    validateBitcoinSelectionUsecase = _MockValidateBitcoinSelectionUsecase();
    when(
      () => validateBitcoinSelectionUsecase.execute(
        walletId: any(named: 'walletId'),
        selectedInputs: any(named: 'selectedInputs'),
      ),
    ).thenAnswer((_) async => []);
    prepareLiquidSendUsecase = _MockPrepareLiquidSendUsecase();
    sendWithPayjoinUsecase = _MockSendWithPayjoinUsecase();
    watchPayjoinUsecase = _MockWatchPayjoinUsecase();
    getWalletsUsecase = _MockGetWalletsUsecase();
    getWalletUsecase = _MockGetWalletUsecase();
    createSendSwapUsecase = _MockCreateSendSwapUsecase();
    getSendSwapQuoteUsecase = _MockGetSendSwapQuoteUsecase();
    createSendCrossChainSwapUsecase = _MockCreateSendCrossChainSwapUsecase();
    getSendCrossChainQuoteUsecase = _MockGetSendCrossChainQuoteUsecase();
    resolveLightningAddressUsecase = _MockResolveLightningAddressUsecase();
    updateSendSwapPayinUsecase = _MockUpdateSendSwapPayinUsecase();
    watchSendSwapUsecase = _MockWatchSendSwapUsecase();
    updatePaidSendSwapUsecase = _MockUpdatePaidSendSwapUsecase();
    watchFinishedWalletSyncsUsecase = _MockWatchFinishedWalletSyncsUsecase();
    signBitcoinTxUsecase = _MockSignBitcoinTxUsecase();
    signLiquidTxUsecase = _MockSignLiquidTxUsecase();
    broadcastBitcoinTxUsecase = _MockBroadcastBitcoinTransactionUsecase();
    broadcastLiquidTxUsecase = _MockBroadcastLiquidTransactionUsecase();
    calculateLiquidAbsoluteFeesUsecase =
        _MockCalculateLiquidAbsoluteFeesUsecase();
    calculateLiquidPsetSizeUsecase = _MockCalculateLiquidPsetSizeUsecase();
    watchWalletTransactionByTxIdUsecase =
        _MockWatchWalletTransactionByTxIdUsecase();
    calculateBitcoinAbsoluteFeesUsecase =
        _MockCalculateBitcoinAbsoluteFeesUsecase();
    verifyChainSwapAmountSendUsecase = _MockVerifyChainSwapAmountSendUsecase();
    verifyExchangePayinUsecase = _MockVerifyExchangePayinUsecase();
    previewBitcoinFeeUsecase = _MockPreviewBitcoinFeeUsecase();
    previewBitcoinFeePresetsUsecase = _MockPreviewBitcoinFeePresetsUsecase();
    checkLiquidConsolidationUsecase = _MockCheckLiquidConsolidationUsecase();
    verifySignedTxUsecase = _MockVerifySignedTxUsecase();
    // A hardware signer that returns what it was asked to sign: the default
    // is acceptance, tests that need a tampered device re-stub it.
    when(
      () => verifySignedTxUsecase.execute(
        unsignedPsbt: any(named: 'unsignedPsbt'),
        signedTxHex: any(named: 'signedTxHex'),
      ),
    ).thenAnswer((_) async {});

    payjoinEvents = StreamController<PayjoinSession>.broadcast();

    // Benign default stubs for everything the payjoin branch (or its
    // aftermath) touches.
    when(
      () => watchPayjoinUsecase.execute(ids: any(named: 'ids')),
    ).thenAnswer((_) => payjoinEvents.stream);
    when(
      () => getWalletUsecase.execute(any(), sync: any(named: 'sync')),
    ).thenAnswer((_) async => _bitcoinLocalWallet());
    when(() => labelsFacade.store(any())).thenAnswer(
      (_) async => Ok<Label, LabelFailure>(
        Label(
          id: 1,
          type: LabelType.transaction,
          label: 'note',
          reference: 'txid',
        ),
      ),
    );
  });

  tearDown(() async {
    await payjoinEvents.close();
  });

  /// Drives the real `signTransaction` so `_watchPayjoin` gets armed against
  /// the mocked [watchPayjoinUsecase] stream, then returns the cubit.
  Future<_TestableSendCubit> armWatcher(
    _TestableSendCubit cubit, {
    String label = '',
  }) async {
    when(
      () => sendWithPayjoinUsecase.execute(
        walletId: any(named: 'walletId'),
        isTestnet: any(named: 'isTestnet'),
        bip21: any(named: 'bip21'),
        unsignedOriginalPsbt: any(named: 'unsignedOriginalPsbt'),
        amountSat: any(named: 'amountSat'),
        networkFeesSatPerVb: any(named: 'networkFeesSatPerVb'),
      ),
    ).thenAnswer((_) async => _sender(status: PayjoinStatus.requested));

    cubit.setStateForTest(payjoinReadyState(label: label));
    await cubit.signTransaction();
    return cubit;
  }

  group('SendCubit._watchPayjoin', () {
    test(
      'confirm starts payjoin even when the regular PSBT was pre-signed',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        when(
          () => sendWithPayjoinUsecase.execute(
            walletId: any(named: 'walletId'),
            isTestnet: any(named: 'isTestnet'),
            bip21: any(named: 'bip21'),
            unsignedOriginalPsbt: any(named: 'unsignedOriginalPsbt'),
            amountSat: any(named: 'amountSat'),
            networkFeesSatPerVb: any(named: 'networkFeesSatPerVb'),
          ),
        ).thenAnswer((_) async => _sender(status: PayjoinStatus.requested));
        cubit.setStateForTest(
          payjoinReadyState().copyWith(
            signedBitcoinPsbt: 'signed-regular-psbt',
          ),
        );

        await cubit.onConfirmTransactionClicked();

        expect(cubit.state.step, SendStep.sending);
        expect(cubit.state.payjoinSender?.status, PayjoinStatus.requested);
        verify(
          () => sendWithPayjoinUsecase.execute(
            walletId: 'w1',
            isTestnet: false,
            bip21: any(named: 'bip21'),
            unsignedOriginalPsbt: 'cHNidP8=',
            amountSat: 50000,
            networkFeesSatPerVb: 2,
          ),
        ).called(1);
        verifyNever(
          () => broadcastBitcoinTxUsecase.execute(
            any(),
            isPsbt: any(named: 'isPsbt'),
          ),
        );
      },
    );

    // The payjoin-only path skips createTransaction(), so nothing else clears
    // a failure left by the previous attempt and every retry gets trapped.
    test(
      'a failed payjoin start can be retried from the confirm screen',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        var attempts = 0;
        when(
          () => sendWithPayjoinUsecase.execute(
            walletId: any(named: 'walletId'),
            isTestnet: any(named: 'isTestnet'),
            bip21: any(named: 'bip21'),
            unsignedOriginalPsbt: any(named: 'unsignedOriginalPsbt'),
            amountSat: any(named: 'amountSat'),
            networkFeesSatPerVb: any(named: 'networkFeesSatPerVb'),
          ),
        ).thenAnswer((_) async {
          attempts++;
          if (attempts == 1) throw Exception('payjoin directory unreachable');
          return _sender(status: PayjoinStatus.requested);
        });
        cubit.setStateForTest(
          payjoinReadyState().copyWith(
            signedBitcoinPsbt: 'signed-regular-psbt',
          ),
        );

        await cubit.onConfirmTransactionClicked();
        expect(cubit.state.step, SendStep.confirm);
        expect(cubit.state.failure, isA<SendTransactionConfirmationFailure>());

        await cubit.onConfirmTransactionClicked();

        expect(attempts, 2);
        expect(cubit.state.step, SendStep.sending);
        expect(cubit.state.payjoinSender?.status, PayjoinStatus.requested);
      },
    );

    test('a completed PayjoinSender (real payjoin, txId set) resolves the flow '
        'to success with the payjoin txid, syncs the wallet and stores the '
        'user label on that final txid', () async {
      final cubit = await armWatcher(buildCubit(), label: 'coffee');
      addTearDown(cubit.close);

      // signTransaction set state.txId = originalTxId provisionally.
      expect(cubit.state.txId, 'sender-orig-txid');
      expect(cubit.state.step, SendStep.confirm);

      payjoinEvents.add(
        _sender(status: PayjoinStatus.completed, txId: 'real-payjoin-txid'),
      );
      await pumpEventQueue();

      expect(cubit.state.step, SendStep.success);
      expect(cubit.state.txId, 'real-payjoin-txid');
      // The wallet is synced (sync: true) once the payjoin resolves.
      verify(() => getWalletUsecase.execute('w1', sync: true)).called(1);
      // The typed label is persisted on the FINAL (payjoin) txid.
      final stored =
          verify(() => labelsFacade.store(captureAny())).captured.single
              as NewLabel;
      expect(stored.reference, 'real-payjoin-txid');
      expect(stored.label, 'coffee');
    });

    test('an aborted PayjoinSender (fallback broadcast, txId null) resolves to '
        'success with the ORIGINAL txid', () async {
      final cubit = await armWatcher(buildCubit());
      addTearDown(cubit.close);

      payjoinEvents.add(_sender(status: PayjoinStatus.aborted));
      await pumpEventQueue();

      expect(cubit.state.step, SendStep.success);
      expect(cubit.state.txId, 'sender-orig-txid');
    });

    test('an expired PayjoinSender returns to confirm with a broadcast-failure '
        'exception AND clears both txId and payjoinSender so a retry starts '
        'clean (C7 regression pin)', () async {
      final cubit = await armWatcher(buildCubit());
      addTearDown(cubit.close);

      // The provisional txId + payjoinSender are set before the event.
      expect(cubit.state.txId, 'sender-orig-txid');
      expect(cubit.state.payjoinSender, isNotNull);

      payjoinEvents.add(_sender(status: PayjoinStatus.expired));
      await pumpEventQueue();

      expect(cubit.state.step, SendStep.confirm);
      expect(cubit.state.failure, isA<SendTransactionConfirmationFailure>());
      expect(
        (cubit.state.failure! as SendTransactionConfirmationFailure)
            .isBroadcastFailure,
        isTrue,
      );
      // The key C7 clear: both must be nulled so broadcastTransaction's
      // `txId != null` guard no longer short-circuits the retry.
      expect(cubit.state.txId, isNull);
      expect(cubit.state.payjoinSender, isNull);
    });

    test(
      'a non-terminal event (requested/proposed) only updates payjoinSender; '
      'the step stays put (not success, not confirm-with-failure)',
      () async {
        final cubit = await armWatcher(buildCubit());
        addTearDown(cubit.close);

        final stepBefore = cubit.state.step;

        payjoinEvents.add(_sender(status: PayjoinStatus.proposed));
        await pumpEventQueue();

        expect(cubit.state.payjoinSender, isNotNull);
        expect(cubit.state.payjoinSender!.status, PayjoinStatus.proposed);
        expect(cubit.state.step, stepBefore);
        expect(cubit.state.step, isNot(SendStep.success));
        expect(cubit.state.failure, isNull);
      },
    );
  });

  group('SendCubit — hardware-signer transaction verification', () {
    SendState hardwareSignReadyState() => SendState(
      step: SendStep.confirm,
      sendType: SendType.bitcoin,
      selectedWallet: _bitcoinLocalWallet(),
      unsignedPsbt: 'cHNidP8=',
      confirmedAmountSat: 50000,
    );

    test('audit reproducer: a signed transaction that fails verification is '
        'refused, never stored for broadcast', () async {
      // Before the fix, updateSignedBitcoinTx stored the device-returned
      // bytes verbatim and onConfirmTransactionClicked broadcast them
      // unchecked, while the confirm screen kept showing the pre-signing
      // address and amount.
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(hardwareSignReadyState());
      when(
        () => verifySignedTxUsecase.execute(
          unsignedPsbt: any(named: 'unsignedPsbt'),
          signedTxHex: any(named: 'signedTxHex'),
        ),
      ).thenThrow(
        VerifySignedTxException('The signed transaction does not match'),
      );

      await cubit.updateSignedBitcoinTx('deadbeef');

      expect(
        cubit.state.signedBitcoinTx,
        isNull,
        reason: 'a tampered transaction must never reach the broadcast path',
      );
      expect(cubit.state.failure, isA<SendTransactionConfirmationFailure>());
    });

    test('a signed transaction passing the output check is stored', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(hardwareSignReadyState());

      await cubit.updateSignedBitcoinTx('deadbeef');

      expect(cubit.state.signedBitcoinTx, 'deadbeef');
      expect(cubit.state.failure, isNull);
      verify(
        () => verifySignedTxUsecase.execute(
          unsignedPsbt: 'cHNidP8=',
          signedTxHex: 'deadbeef',
        ),
      ).called(1);
    });

    test('a valid retry clears the previous verification error', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setStateForTest(hardwareSignReadyState());
      var attempts = 0;
      when(
        () => verifySignedTxUsecase.execute(
          unsignedPsbt: any(named: 'unsignedPsbt'),
          signedTxHex: any(named: 'signedTxHex'),
        ),
      ).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) {
          throw VerifySignedTxException(
            'The signed transaction does not match',
          );
        }
      });

      expect(await cubit.updateSignedBitcoinTx('tampered'), isFalse);
      expect(cubit.state.failure, isA<SendTransactionConfirmationFailure>());

      expect(await cubit.updateSignedBitcoinTx('valid'), isTrue);
      expect(cubit.state.signedBitcoinTx, 'valid');
      expect(cubit.state.failure, isNull);
    });

    test(
      'a signed transaction with no unsigned PSBT in state is refused',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        cubit.setStateForTest(
          hardwareSignReadyState().copyWith(unsignedPsbt: null),
        );

        await cubit.updateSignedBitcoinTx('deadbeef');

        expect(cubit.state.signedBitcoinTx, isNull);
        expect(cubit.state.failure, isA<SendTransactionConfirmationFailure>());
        verifyNever(
          () => verifySignedTxUsecase.execute(
            unsignedPsbt: any(named: 'unsignedPsbt'),
            signedTxHex: any(named: 'signedTxHex'),
          ),
        );
      },
    );
  });

  group('SendCubit.onAmountConfirmed note handling', () {
    /// A Lightning send whose invoice carries a description. The description is
    /// the only record of what the payment was for, and the note is what ends
    /// up as a label on the sender's own transaction — so an empty note takes
    /// the description rather than dropping it. A note the user typed always
    /// wins over the description.
    SendState lightningReadyState({String label = ''}) => SendState(
      step: SendStep.confirm,
      sendType: SendType.lightning,
      selectedWallet: _bitcoinLocalWallet(),
      paymentRequest: const PaymentRequest.bolt11(
        invoice: 'lnbc1-invoice',
        amountSat: 50000,
        paymentHash: 'hash',
        description: 'Order 123456',
        expiresAt: 0,
        isTestnet: false,
      ),
      label: label,
    );

    /// Stops `onAmountConfirmed` right after the emit under test: the quote
    /// lookup is the next call and returning an error makes it bail out.
    void stubQuoteFailure() {
      when(
        () => getSendSwapQuoteUsecase.execute(
          wallet: any(named: 'wallet'),
          amountSat: any(named: 'amountSat'),
        ),
      ).thenAnswer((_) async => const Err(SendInvoiceExpiredFailure()));
    }

    test('an empty note is seeded with the invoice description', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      stubQuoteFailure();
      cubit.setStateForTest(lightningReadyState());

      await cubit.onAmountConfirmed();

      expect(cubit.state.lightningInvoice, isNotNull);
      expect(cubit.state.label, 'Order 123456');
    });

    test('a note the user typed overrides the invoice description', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      stubQuoteFailure();
      cubit.setStateForTest(lightningReadyState(label: 'coffee'));

      await cubit.onAmountConfirmed();

      expect(cubit.state.label, 'coffee');
    });
  });

  group('SendCubit.broadcastTransaction - BIP21 advertising pj without an '
      'attempted payjoin', () {
    SendState plainSignedState({String label = ''}) => SendState(
      step: SendStep.sending,
      sendType: SendType.bitcoin,
      selectedWallet: _bitcoinLocalWallet(),
      paymentRequest: _payjoinBip21(),
      payjoinGloballyEnabled: false,
      isToSelf: false,
      signedBitcoinPsbt: 'signed-psbt',
      label: label,
    );

    void stubBroadcast() {
      when(
        () => broadcastBitcoinTxUsecase.execute(
          any(),
          isPsbt: any(named: 'isPsbt'),
        ),
      ).thenAnswer((_) async => 'broadcast-txid');
    }

    test(
      'broadcasts the signed transaction and succeeds with its txid',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        stubBroadcast();
        cubit.setStateForTest(plainSignedState());

        await cubit.broadcastTransaction();

        verify(
          () => broadcastBitcoinTxUsecase.execute('signed-psbt', isPsbt: true),
        ).called(1);
        expect(cubit.state.txId, 'broadcast-txid');
        expect(cubit.state.step, SendStep.success);
        expect(cubit.state.failure, isNull);
      },
    );

    test('with a user label, stores the label on the broadcast txid', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      stubBroadcast();
      cubit.setStateForTest(plainSignedState(label: 'coffee'));

      await cubit.broadcastTransaction();

      verify(
        () => broadcastBitcoinTxUsecase.execute('signed-psbt', isPsbt: true),
      ).called(1);
      expect(cubit.state.txId, 'broadcast-txid');
      expect(cubit.state.step, SendStep.success);
      expect(cubit.state.failure, isNull);
      final stored =
          verify(() => labelsFacade.store(captureAny())).captured.single
              as NewLabel;
      expect(stored.reference, 'broadcast-txid');
      expect(stored.label, 'coffee');
    });
  });

  test(
    'does not broadcast when a selected coin becomes unavailable during validation',
    () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      final selected = _utxo(amountSat: 10000);
      when(
        () => validateBitcoinSelectionUsecase.execute(
          walletId: 'w-bitcoin',
          selectedInputs: [selected],
        ),
      ).thenThrow(NoSpendableUtxoException('selected coin disappeared'));
      cubit.setStateForTest(
        SendState(
          step: SendStep.confirm,
          selectedWallet: _bitcoinWallet(balanceSat: 20000),
          selectedUtxos: [selected],
          unsignedPsbt: 'unsigned-psbt',
          signedBitcoinPsbt: 'signed-psbt',
        ),
      );

      await cubit.broadcastTransaction();

      expect(cubit.state.failure, isA<SendSelectedCoinsUnavailableFailure>());
      expect(cubit.state.unsignedPsbt, isNull);
      expect(cubit.state.signedBitcoinPsbt, isNull);
      verifyNever(
        () => broadcastBitcoinTxUsecase.execute(
          any(),
          isPsbt: any(named: 'isPsbt'),
        ),
      );
    },
  );

  group('SendCubit payment request input', () {
    test('stores sanitized input while parsing it', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      const parsed = PaymentRequest.lnAddress(address: 'user@example.com');
      when(
        () => detectBitcoinStringUsecase.execute(data: 'user@example.com'),
      ).thenAnswer((_) async => parsed);

      await cubit.onChangedText('  "user@example.com"  ');

      expect(cubit.state.copiedRawPaymentRequest, 'user@example.com');
      expect(cubit.state.paymentRequest, parsed);
      verify(
        () => detectBitcoinStringUsecase.execute(data: 'user@example.com'),
      ).called(1);
    });

    test('parses the current input when continuing', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      when(
        () => detectBitcoinStringUsecase.execute(data: 'invalid-address'),
      ).thenThrow(StateError('invalid'));

      cubit.onChangedText('invalid-address');
      await cubit.continueOnAddressConfirmed();

      verify(
        () => detectBitcoinStringUsecase.execute(data: 'invalid-address'),
      ).called(1);
      expect(cubit.state.paymentRequest, isNull);
      expect(cubit.state.failure, isA<SendInvalidPaymentRequestFailure>());
      expect(cubit.state.loadingBestWallet, isFalse);
    });

    test('waits for current input parsing before validating', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      final parsing = Completer<PaymentRequest>();
      when(
        () => detectBitcoinStringUsecase.execute(data: 'pending-address'),
      ).thenAnswer((_) => parsing.future);

      final input = cubit.onChangedText('pending-address');
      var submitCompleted = false;
      final submit = cubit.continueOnAddressConfirmed().whenComplete(
        () => submitCompleted = true,
      );
      await Future<void>.delayed(Duration.zero);

      try {
        expect(submitCompleted, isFalse);
      } finally {
        parsing.completeError(StateError('invalid'));
        await input;
        await submit;
      }
      expect(cubit.state.failure, isA<SendInvalidPaymentRequestFailure>());
      expect(cubit.state.loadingBestWallet, isFalse);
    });

    test('treats normalized empty input as clear', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      when(
        () => detectBitcoinStringUsecase.execute(data: ''),
      ).thenThrow(StateError('empty'));

      await cubit.onChangedText('  ""  ');

      expect(cubit.state.copiedRawPaymentRequest, isEmpty);
      expect(cubit.state.paymentRequest, isNull);
      expect(cubit.state.failure, isNull);
    });

    test(
      'keeps a newer valid submit result when an older one completes',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        final oldResult = Completer<PaymentRequest>();
        final newResult = Completer<PaymentRequest>();
        when(
          () => detectBitcoinStringUsecase.execute(data: any(named: 'data')),
        ).thenAnswer((invocation) {
          final data = invocation.namedArguments[#data] as String;
          return data == 'old-address' ? oldResult.future : newResult.future;
        });

        cubit.onChangedText('old-address');
        final oldSubmit = cubit.continueOnAddressConfirmed();
        cubit.onChangedText('new-address');
        final newSubmit = cubit.continueOnAddressConfirmed();
        newResult.complete(
          const PaymentRequest.lnAddress(address: 'new@example.com'),
        );
        await newSubmit;
        oldResult.complete(
          const PaymentRequest.bitcoin(address: 'old', isTestnet: true),
        );
        await oldSubmit;

        expect(cubit.state.copiedRawPaymentRequest, 'new-address');
        expect(
          cubit.state.paymentRequest,
          const PaymentRequest.lnAddress(address: 'new@example.com'),
        );
      },
    );

    test(
      'ignores an obsolete recipient result while keeping the current input',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        final oldParsing = Completer<PaymentRequest>();
        final newParsing = Completer<PaymentRequest>();
        when(
          () => detectBitcoinStringUsecase.execute(data: any(named: 'data')),
        ).thenAnswer((invocation) {
          final data = invocation.namedArguments[#data] as String;
          return data == 'old-address' ? oldParsing.future : newParsing.future;
        });
        cubit.setStateForTest(
          const SendState(
            copiedRawPaymentRequest: 'old-address',
            paymentRequest: PaymentRequest.bitcoin(
              address: 'old-address',
              isTestnet: true,
            ),
          ),
        );

        final oldFuture = cubit.onChangedText('old-address');
        final newFuture = cubit.onChangedText('new-address');
        expect(cubit.state.copiedRawPaymentRequest, 'new-address');
        expect(cubit.state.paymentRequest, isNull);

        oldParsing.complete(
          const PaymentRequest.bitcoin(address: 'old', isTestnet: true),
        );
        await oldFuture;
        expect(cubit.state.paymentRequest, isNull);

        newParsing.complete(
          const PaymentRequest.lnAddress(address: 'new@example.com'),
        );
        await newFuture;

        expect(
          cubit.state.paymentRequest,
          const PaymentRequest.lnAddress(address: 'new@example.com'),
        );
        verify(
          () => detectBitcoinStringUsecase.execute(data: 'old-address'),
        ).called(1);
        verify(
          () => detectBitcoinStringUsecase.execute(data: 'new-address'),
        ).called(1);
      },
    );

    test('keeps a newer valid result when an older parse fails', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      final oldResult = Completer<PaymentRequest>();
      final newResult = Completer<PaymentRequest>();
      when(
        () => detectBitcoinStringUsecase.execute(data: any(named: 'data')),
      ).thenAnswer((invocation) {
        final data = invocation.namedArguments[#data] as String;
        return data == 'old-address' ? oldResult.future : newResult.future;
      });

      cubit.onChangedText('old-address');
      final oldSubmit = cubit.continueOnAddressConfirmed();
      cubit.onChangedText('new-address');
      final newSubmit = cubit.continueOnAddressConfirmed();
      newResult.complete(
        const PaymentRequest.lnAddress(address: 'new@example.com'),
      );
      await newSubmit;
      oldResult.completeError(StateError('old input is invalid'));
      await oldSubmit;

      expect(
        cubit.state.paymentRequest,
        const PaymentRequest.lnAddress(address: 'new@example.com'),
      );
    });

    test(
      'stops an obsolete continuation resumed after wallet utxos load',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        final wallet = _bitcoinWallet(balanceSat: 100000);
        final oldUtxosLoaded = Completer<List<WalletUtxo>>();
        const oldRequest = PaymentRequest.bitcoin(
          address: 'old-address',
          isTestnet: false,
        );
        const newRequest = PaymentRequest.lnAddress(address: 'new@example.com');

        when(
          () => bestWalletUsecase.execute(
            wallets: any(named: 'wallets'),
            request: any(named: 'request'),
            amountSat: any(named: 'amountSat'),
          ),
        ).thenReturn(wallet);
        when(
          () => getWalletUtxosUsecase.execute(walletId: wallet.id),
        ).thenAnswer((_) => oldUtxosLoaded.future);
        when(
          () => checkLiquidConsolidationUsecase.execute(walletId: wallet.id),
        ).thenAnswer((_) async => false);
        when(
          () => getNetworkFeesUsecase.execute(isLiquid: any(named: 'isLiquid')),
        ).thenAnswer((_) async => _feeOptions());
        when(
          () => watchFinishedWalletSyncsUsecase.execute(walletId: wallet.id),
        ).thenAnswer((_) => const Stream<Wallet>.empty());

        final oldContinuation = cubit.onScannedPaymentRequest(
          'old-address',
          oldRequest,
        );
        await untilCalled(
          () => getWalletUtxosUsecase.execute(walletId: wallet.id),
        );
        verify(
          () => getWalletUtxosUsecase.execute(walletId: wallet.id),
        ).called(1);

        final newContinuation = cubit.onScannedPaymentRequest(
          'new@example.com',
          newRequest,
        );
        await newContinuation;
        expect(cubit.state.sendType, SendType.lightning);

        oldUtxosLoaded.complete(const <WalletUtxo>[]);
        await oldContinuation;

        expect(
          cubit.state.sendType,
          SendType.lightning,
          reason:
              'an obsolete continuation must not overwrite the current send type',
        );
        verify(
          () => getNetworkFeesUsecase.execute(isLiquid: any(named: 'isLiquid')),
        ).called(2);
      },
    );

    test('stops an obsolete continuation resumed after fees load', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      final wallet = _bitcoinWallet(balanceSat: 100000);
      final oldBitcoinFeesLoaded = Completer<FeeOptions>();
      const oldRequest = PaymentRequest.bitcoin(
        address: 'old-address',
        isTestnet: false,
      );
      const newRequest = PaymentRequest.lnAddress(address: 'new@example.com');

      when(
        () => bestWalletUsecase.execute(
          wallets: any(named: 'wallets'),
          request: any(named: 'request'),
          amountSat: any(named: 'amountSat'),
        ),
      ).thenReturn(wallet);
      when(
        () => getWalletUtxosUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) async => const <WalletUtxo>[]);
      when(
        () => checkLiquidConsolidationUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) async => false);
      when(
        () => getNetworkFeesUsecase.execute(isLiquid: false),
      ).thenAnswer((_) => oldBitcoinFeesLoaded.future);
      when(
        () => getNetworkFeesUsecase.execute(isLiquid: true),
      ).thenAnswer((_) async => _feeOptions());
      when(
        () => watchFinishedWalletSyncsUsecase.execute(walletId: wallet.id),
      ).thenAnswer((_) => const Stream<Wallet>.empty());
      when(
        () => detectBitcoinStringUsecase.execute(data: 'new@example.com'),
      ).thenAnswer((_) async => newRequest);

      final oldContinuation = cubit.onScannedPaymentRequest(
        'old-address',
        oldRequest,
      );
      await untilCalled(() => getNetworkFeesUsecase.execute(isLiquid: false));

      await cubit.onChangedText('new@example.com');
      expect(cubit.state.step, SendStep.address);

      oldBitcoinFeesLoaded.complete(_feeOptions());
      await oldContinuation;

      expect(cubit.state.paymentRequest, newRequest);
      expect(
        cubit.state.step,
        SendStep.address,
        reason: 'an obsolete continuation must not advance the current input',
      );
    });

    test('uses a scanned payment request without reparsing it', () async {
      const request = PaymentRequest.lnAddress(address: 'user@example.com');
      final cubit = buildCubit();
      addTearDown(cubit.close);

      // The scanner already supplied the parsed request; this assertion only
      // covers the input boundary before the remainder of the flow runs.
      await cubit.onScannedPaymentRequest('  user@example.com  ', request);

      expect(cubit.state.copiedRawPaymentRequest, 'user@example.com');
      expect(cubit.state.paymentRequest, request);
      verifyNever(
        () => detectBitcoinStringUsecase.execute(data: any(named: 'data')),
      );
    });
  });

  group('SendCubit.loadUtxos', () {
    test(
      'drops a missing selected coin and invalidates its transaction',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        final selected = _utxo(amountSat: 10000);
        when(
          () => getWalletUtxosUsecase.execute(walletId: 'w-bitcoin'),
        ).thenAnswer((_) async => const <WalletUtxo>[]);
        cubit.setStateForTest(
          SendState(
            selectedWallet: _bitcoinWallet(balanceSat: 20000),
            utxos: [selected],
            selectedUtxos: [selected],
            unsignedPsbt: 'unsigned-psbt',
            signedBitcoinPsbt: 'signed-psbt',
          ),
        );

        await cubit.loadUtxos();

        expect(cubit.state.utxos, isEmpty);
        expect(cubit.state.selectedUtxos, isEmpty);
        expect(cubit.state.failure, isA<SendSelectedCoinsUnavailableFailure>());
        expect(cubit.state.unsignedPsbt, isNull);
        expect(cubit.state.signedBitcoinPsbt, isNull);
      },
    );
  });

  // A shortfall used to show "Build Failed", the same message as a dead
  // Electrum server or a bad address.
  group('SendCubit.createTransaction shortfalls', () {
    test(
      'a selected coin that disappears is unavailable, not insufficient',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        final selected = _utxo(amountSat: 10000);
        when(
          () => prepareBitcoinSendUsecase.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
            networkFee: any(named: 'networkFee'),
            amountSat: any(named: 'amountSat'),
            drain: any(named: 'drain'),
            selectedInputs: any(named: 'selectedInputs'),
            replaceByFee: any(named: 'replaceByFee'),
          ),
        ).thenThrow(NoSpendableUtxoException('selected coin disappeared'));
        when(
          () => getWalletUtxosUsecase.execute(walletId: any(named: 'walletId')),
        ).thenAnswer((_) async => [selected]);
        cubit.setStateForTest(
          SendState(
            step: SendStep.amount,
            sendType: SendType.bitcoin,
            selectedWallet: _bitcoinWallet(balanceSat: 20000),
            paymentRequest: const PaymentRequest.bitcoin(
              address: 'bc1-address',
              isTestnet: false,
            ),
            amount: '5000',
            confirmedAmountSat: 5000,
            inputAmountCurrencyCode: 'sats',
            bitcoinFeesList: _feeOptions(),
            liquidFeesList: _feeOptions(),
            selectedUtxos: [selected],
          ),
        );

        when(
          () => getWalletUtxosUsecase.execute(walletId: any(named: 'walletId')),
        ).thenAnswer((_) async => [selected]);
        when(
          () => checkLiquidConsolidationUsecase.execute(
            walletId: any(named: 'walletId'),
          ),
        ).thenAnswer((_) async => false);

        await cubit.createTransaction();

        expect(cubit.state.failure, isA<SendSelectedCoinsUnavailableFailure>());
        expect(
          cubit.state.failure,
          isNot(isA<SendSelectedCoinsInsufficientFailure>()),
        );
      },
    );

    test(
      'a shortfall at build time is an insufficient-balance failure',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        when(
          () => prepareLiquidSendUsecase.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
            feeRate: any(named: 'feeRate'),
            amountSat: any(named: 'amountSat'),
            drain: any(named: 'drain'),
          ),
        ).thenThrow(
          InsufficientFundsException(
            'InsufficientFunds { missing_sats: 2, is_token: false }',
          ),
        );
        when(
          () => getWalletUtxosUsecase.execute(walletId: any(named: 'walletId')),
        ).thenAnswer((_) async => <WalletUtxo>[]);
        cubit.setStateForTest(
          SendState(
            step: SendStep.amount,
            sendType: SendType.liquid,
            selectedWallet: _liquidWallet(balanceSat: 20000),
            paymentRequest: const PaymentRequest.liquid(
              address: 'lq1-address',
              isTestnet: false,
            ),
            amount: '19998',
            inputAmountCurrencyCode: 'sats',
            liquidFeesList: _feeOptions(),
            bitcoinFeesList: _feeOptions(),
          ),
        );

        when(
          () => checkLiquidConsolidationUsecase.execute(
            walletId: any(named: 'walletId'),
          ),
        ).thenAnswer((_) async => false);

        await cubit.createTransaction();

        expect(cubit.state.failure, isA<SendInsufficientFundsForFeesFailure>());
        expect(cubit.state.failure, isNot(isA<SendTransactionBuildFailure>()));
        // and it must not move on to confirm with no transaction built
        expect(cubit.state.step, SendStep.amount);
      },
    );

    // With hand-picked coins the amount was only checked against the whole
    // balance, so the shortfall may be the selection rather than the fee.
    test(
      'with hand-picked coins the message identifies selection shortfall',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);
        when(
          () => prepareBitcoinSendUsecase.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
            networkFee: any(named: 'networkFee'),
            amountSat: any(named: 'amountSat'),
            drain: any(named: 'drain'),
            selectedInputs: any(named: 'selectedInputs'),
            replaceByFee: any(named: 'replaceByFee'),
          ),
        ).thenThrow(InsufficientFundsException('needed 5000, available 1000'));
        final selected = _utxo(amountSat: 1000);
        // loadUtxos() filters the selection against the wallet's current UTXOs,
        // so the picked coin has to be in the list or the selection is dropped.
        when(
          () => getWalletUtxosUsecase.execute(walletId: any(named: 'walletId')),
        ).thenAnswer((_) async => [selected]);
        cubit.setStateForTest(
          SendState(
            step: SendStep.amount,
            sendType: SendType.bitcoin,
            selectedWallet: _bitcoinWallet(balanceSat: 20000),
            paymentRequest: const PaymentRequest.bitcoin(
              address: 'bc1-address',
              isTestnet: false,
            ),
            amount: '5000',
            confirmedAmountSat: 5000,
            inputAmountCurrencyCode: 'sats',
            liquidFeesList: _feeOptions(),
            bitcoinFeesList: _feeOptions(),
            selectedUtxos: [selected],
          ),
        );

        await cubit.createTransaction();

        expect(
          cubit.state.failure,
          isA<SendSelectedCoinsInsufficientFailure>(),
        );
        expect(
          cubit.state.failure,
          isNot(isA<SendInsufficientFundsForFeesFailure>()),
        );
        final captured = verify(
          () => prepareBitcoinSendUsecase.execute(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
            networkFee: any(named: 'networkFee'),
            amountSat: captureAny(named: 'amountSat'),
            drain: any(named: 'drain'),
            selectedInputs: captureAny(named: 'selectedInputs'),
            replaceByFee: any(named: 'replaceByFee'),
          ),
        ).captured;
        expect(captured[0], 5000);
        expect(captured[1] as List<WalletUtxo>, [selected]);
      },
    );

    // #2337: frozen coins cause a shortfall too, and only the generic failure
    // reaches the "manage coins" hint that tells the user what to do.
    test('with frozen coins the message stays generic', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      when(
        () => prepareBitcoinSendUsecase.execute(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
          networkFee: any(named: 'networkFee'),
          amountSat: any(named: 'amountSat'),
          drain: any(named: 'drain'),
          selectedInputs: any(named: 'selectedInputs'),
          replaceByFee: any(named: 'replaceByFee'),
        ),
      ).thenThrow(InsufficientFundsException('needed 10000, available 5000'));
      when(
        () => getWalletUtxosUsecase.execute(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => [_utxo(amountSat: 15000, isFrozen: true)]);
      cubit.setStateForTest(
        SendState(
          step: SendStep.amount,
          sendType: SendType.bitcoin,
          selectedWallet: _bitcoinWallet(balanceSat: 20000),
          paymentRequest: const PaymentRequest.bitcoin(
            address: 'bc1-address',
            isTestnet: false,
          ),
          // Fits the 20000 balance, but 15000 of it is frozen.
          amount: '10000',
          inputAmountCurrencyCode: 'sats',
          liquidFeesList: _feeOptions(),
          bitcoinFeesList: _feeOptions(),
        ),
      );

      await cubit.onAmountConfirmed();

      expect(cubit.state.frozenBalanceSat, 15000);
      expect(cubit.state.failure, isA<SendInsufficientBalanceFailure>());
      expect(
        cubit.state.failure,
        isNot(isA<SendInsufficientFundsForFeesFailure>()),
      );
    });
  });
}
