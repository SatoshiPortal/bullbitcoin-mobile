// Behavioral proof for two audit findings on SendCubit:
//
// 1. `_invalidateSignedTransaction()` (added by `fix(send)`) only clears
//    `signedBitcoinTx`. The BDK path stores its signed payload in
//    `signedBitcoinPsbt`, which survives every payment edit and is the value
//    `onConfirmTransactionClicked()` broadcasts.
// 2. `broadcastTransaction()` guards its `emit`s with `isClosed` but still
//    dereferences `state.txId!` for the post-broadcast bookkeeping, so a cubit
//    closed mid-broadcast throws instead of recording the send.
import 'dart:async';

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
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
import 'package:bb_mobile/features/send/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/update_paid_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/update_send_swap_payin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/verify_signed_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/verify_exchange_payin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:flutter_test/flutter_test.dart';
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

class _MockGetAvailableCurrenciesUsecase extends Mock
    implements GetAvailableCurrenciesUsecase {}

class _MockGetWalletUtxosUsecase extends Mock
    implements GetWalletUtxosUsecase {}

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

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class _MockCreateSendSwapUsecase extends Mock
    implements CreateSendSwapUsecase {}

class _MockUpdatePaidSendSwapUsecase extends Mock
    implements UpdatePaidSendSwapUsecase {}

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

class _MockSendWithPayjoinUsecase extends Mock
    implements SendWithPayjoinUsecase {}

class _MockWatchPayjoinUsecase extends Mock implements WatchPayjoinUsecase {}

class _MockWatchFinishedWalletSyncsUsecase extends Mock
    implements WatchFinishedWalletSyncsUsecase {}

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

/// Exposes `emit` so a test can start from a realistic mid-flow state.
class _TestSendCubit extends SendCubit {
  _TestSendCubit({
    required super.labelsFacade,
    required super.bestWalletUsecase,
    required super.detectBitcoinStringUsecase,
    required super.getSettingsUsecase,
    required super.convertSatsToCurrencyAmountUsecase,
    required super.getNetworkFeesUsecase,
    required super.getAvailableCurrenciesUsecase,
    required super.getWalletUtxosUsecase,
    required super.prepareBitcoinSendUsecase,
    required super.prepareLiquidSendUsecase,
    required super.signBitcoinTxUsecase,
    required super.signLiquidTxUsecase,
    required super.broadcastBitcoinTxUsecase,
    required super.broadcastLiquidTxUsecase,
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
    required super.sendWithPayjoinUsecase,
    required super.watchPayjoinUsecase,
    required super.watchFinishedWalletSyncsUsecase,
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
  });

  void seed(SendState state) => emit(state);
}

final _wallet = Wallet(
  origin: 'wpkh([aabbccdd/84h/0h/0h])',
  label: 'Secure Bitcoin',
  network: Network.bitcoinMainnet,
  isDefault: true,
  masterFingerprint: 'aabbccdd',
  xpubFingerprint: 'aabbccdd',
  scriptType: ScriptType.bip84,
  xpub: 'xpub',
  externalPublicDescriptor: 'desc',
  internalPublicDescriptor: 'desc',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(1000000),
);

void main() {
  late _MockBroadcastBitcoinTransactionUsecase broadcastBitcoinTx;
  late _MockLabelsFacade labelsFacade;
  late _MockGetWalletUsecase getWalletUsecase;
  late _MockGetWalletUtxosUsecase getWalletUtxosUsecase;
  late _MockCheckLiquidConsolidationUsecase checkLiquidConsolidationUsecase;
  late _MockPrepareLiquidSendUsecase prepareLiquidSendUsecase;
  late _MockCalculateLiquidAbsoluteFeesUsecase
  calculateLiquidAbsoluteFeesUsecase;
  late _TestSendCubit cubit;

  setUpAll(() {
    registerFallbackValue(
      NewLabel.tx(transactionId: 'fallback', label: 'fallback'),
    );
    registerFallbackValue(const RelativeFee(250));
  });

  setUp(() {
    broadcastBitcoinTx = _MockBroadcastBitcoinTransactionUsecase();
    labelsFacade = _MockLabelsFacade();
    getWalletUsecase = _MockGetWalletUsecase();
    getWalletUtxosUsecase = _MockGetWalletUtxosUsecase();
    checkLiquidConsolidationUsecase = _MockCheckLiquidConsolidationUsecase();
    prepareLiquidSendUsecase = _MockPrepareLiquidSendUsecase();
    calculateLiquidAbsoluteFeesUsecase =
        _MockCalculateLiquidAbsoluteFeesUsecase();

    cubit = _TestSendCubit(
      labelsFacade: labelsFacade,
      bestWalletUsecase: _MockSelectBestWalletUsecase(),
      detectBitcoinStringUsecase: _MockDetectBitcoinStringUsecase(),
      getSettingsUsecase: _MockGetSettingsUsecase(),
      convertSatsToCurrencyAmountUsecase:
          _MockConvertSatsToCurrencyAmountUsecase(),
      getNetworkFeesUsecase: _MockGetNetworkFeesUsecase(),
      getAvailableCurrenciesUsecase: _MockGetAvailableCurrenciesUsecase(),
      getWalletUtxosUsecase: getWalletUtxosUsecase,
      prepareBitcoinSendUsecase: _MockPrepareBitcoinSendUsecase(),
      prepareLiquidSendUsecase: prepareLiquidSendUsecase,
      signBitcoinTxUsecase: _MockSignBitcoinTxUsecase(),
      signLiquidTxUsecase: _MockSignLiquidTxUsecase(),
      broadcastBitcoinTxUsecase: broadcastBitcoinTx,
      broadcastLiquidTxUsecase: _MockBroadcastLiquidTransactionUsecase(),
      getWalletsUsecase: _MockGetWalletsUsecase(),
      getWalletUsecase: getWalletUsecase,
      createSendSwapUsecase: _MockCreateSendSwapUsecase(),
      getSendSwapQuoteUsecase: _MockGetSendSwapQuoteUsecase(),
      createSendCrossChainSwapUsecase: _MockCreateSendCrossChainSwapUsecase(),
      getSendCrossChainQuoteUsecase: _MockGetSendCrossChainQuoteUsecase(),
      resolveLightningAddressUsecase: _MockResolveLightningAddressUsecase(),
      updateSendSwapPayinUsecase: _MockUpdateSendSwapPayinUsecase(),
      watchSendSwapUsecase: _MockWatchSendSwapUsecase(),
      updatePaidSendSwapUsecase: _MockUpdatePaidSendSwapUsecase(),
      sendWithPayjoinUsecase: _MockSendWithPayjoinUsecase(),
      watchPayjoinUsecase: _MockWatchPayjoinUsecase(),
      watchFinishedWalletSyncsUsecase: _MockWatchFinishedWalletSyncsUsecase(),
      calculateLiquidAbsoluteFeesUsecase: calculateLiquidAbsoluteFeesUsecase,
      calculateLiquidPsetSizeUsecase: _MockCalculateLiquidPsetSizeUsecase(),
      watchWalletTransactionByTxIdUsecase:
          _MockWatchWalletTransactionByTxIdUsecase(),
      calculateBitcoinAbsoluteFeesUsecase:
          _MockCalculateBitcoinAbsoluteFeesUsecase(),
      verifyChainSwapAmountSendUsecase: _MockVerifyChainSwapAmountSendUsecase(),
      verifyExchangePayinUsecase: _MockVerifyExchangePayinUsecase(),
      previewBitcoinFeeUsecase: _MockPreviewBitcoinFeeUsecase(),
      previewBitcoinFeePresetsUsecase: _MockPreviewBitcoinFeePresetsUsecase(),
      checkLiquidConsolidationUsecase: checkLiquidConsolidationUsecase,
      getSendPayjoinEnabledUsecase: _MockGetSendPayjoinEnabledUsecase(),
      verifySignedTxUsecase: _MockVerifySignedTxUsecase(),
    );
  });

  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
  });

  group('signed payload invalidation', () {
    test('going back to edit the payment drops the signed BDK PSBT', () {
      cubit.seed(
        const SendState(
          step: SendStep.confirm,
          unsignedPsbt: 'cHNidP8BAHECAAAA-unsigned',
          signedBitcoinPsbt: 'cHNidP8BAHECAAAA-signed',
        ),
      );

      cubit.backClicked();

      expect(
        cubit.state.signedBitcoinPsbt,
        isNull,
        reason: 'a payment edit must never leave a broadcastable signed PSBT',
      );
    });

    test('changing the amount drops the signed BDK PSBT', () async {
      cubit.seed(
        const SendState(
          step: SendStep.amount,
          amount: '1000',
          signedBitcoinPsbt: 'cHNidP8BAHECAAAA-signed',
        ),
      );

      await cubit.amountChanged(amount: '999999');

      expect(cubit.state.signedBitcoinPsbt, isNull);
    });
  });

  group('send MAX', () {
    test('caps MAX at the spendable balance, excluding frozen coins', () async {
      const walletBalanceSat = 140000;
      const frozenSat = 40000;
      const absoluteFeesSat = 500;

      final liquidWallet = Wallet(
        origin: 'ct(slip77(..))',
        label: 'Instant payments',
        network: Network.liquidMainnet,
        isDefault: true,
        masterFingerprint: 'aabbccdd',
        xpubFingerprint: 'aabbccdd',
        scriptType: ScriptType.bip84,
        xpub: 'xpub',
        externalPublicDescriptor: 'desc',
        internalPublicDescriptor: 'desc',
        signer: SignerEntity.local,
        signerDevice: null,
        balanceSat: BigInt.from(walletBalanceSat),
      );

      WalletUtxo utxo({required int amountSat, required bool isFrozen}) =>
          WalletUtxo.liquid(
            walletId: liquidWallet.id,
            txId: 'utxo-$amountSat',
            vout: 0,
            scriptPubkey: '00',
            amountSat: BigInt.from(amountSat),
            standardAddress: 'ex1qstandard',
            confidentialAddress: 'lq1qconfidential',
            isFrozen: isFrozen,
          );

      when(
        () => getWalletUtxosUsecase.execute(walletId: any(named: 'walletId')),
      ).thenAnswer(
        (_) async => [
          utxo(amountSat: walletBalanceSat - frozenSat, isFrozen: false),
          utxo(amountSat: frozenSat, isFrozen: true),
        ],
      );
      when(
        () => checkLiquidConsolidationUsecase.execute(
          walletId: any(named: 'walletId'),
        ),
      ).thenAnswer((_) async => false);
      when(
        () => prepareLiquidSendUsecase.execute(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
          feeRate: any(named: 'feeRate'),
          amountSat: any(named: 'amountSat'),
          drain: any(named: 'drain'),
        ),
      ).thenAnswer((_) async => 'pset-base64');
      when(
        () => calculateLiquidAbsoluteFeesUsecase.execute(
          pset: any(named: 'pset'),
        ),
      ).thenAnswer((_) async => absoluteFeesSat);

      // RelativeFee carries sat/kwu: 500 = 2 sat/vB, 25 = the 0.1 relay floor.
      const feeOptions = FeeOptions(
        fastest: RelativeFee(500),
        economic: RelativeFee(250),
        slow: RelativeFee(250),
        minRelay: RelativeFee(25),
      );

      cubit.seed(
        SendState(
          step: SendStep.amount,
          selectedWallet: liquidWallet,
          sendMax: true,
          copiedRawPaymentRequest: 'ex1qrecipient',
          bitcoinFeesList: feeOptions,
          liquidFeesList: feeOptions,
        ),
      );

      await cubit.createTransaction();

      expect(
        cubit.state.confirmedAmountSat,
        walletBalanceSat - frozenSat - absoluteFeesSat,
        reason: 'frozen coins are not spendable, so MAX cannot include them',
      );
    });
  });

  group('broadcast bookkeeping', () {
    test('a cubit closed mid-broadcast still records the send', () async {
      final broadcast = Completer<String>();
      when(
        () => broadcastBitcoinTx.execute(any(), isPsbt: any(named: 'isPsbt')),
      ).thenAnswer((_) => broadcast.future);
      when(() => labelsFacade.store(any())).thenAnswer(
        (invocation) async =>
            Ok(Label.tx(id: 1, transactionId: 'broadcast-txid', label: 'rent')),
      );
      when(
        () => getWalletUsecase.execute(any(), sync: any(named: 'sync')),
      ).thenAnswer((_) async => _wallet);

      cubit.seed(
        SendState(
          step: SendStep.sending,
          selectedWallet: _wallet,
          signedBitcoinPsbt: 'cHNidP8BAHECAAAA-signed',
          label: 'rent',
        ),
      );

      final pending = cubit.broadcastTransaction();
      await cubit.close();
      broadcast.complete('broadcast-txid');

      await expectLater(
        pending,
        completes,
        reason: 'closing the screen must not turn a broadcast into a crash',
      );
      verify(() => labelsFacade.store(any())).called(1);
    });
  });
}
