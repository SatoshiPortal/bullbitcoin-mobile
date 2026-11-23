import 'package:bb_mobile/features/send/domain/usecases/load_send_display_preferences_usecase.dart';

import 'domain/usecases/get_send_amount_quotes_usecase.dart';

import 'package:bull_ark/bull_ark.dart' show ArkFacade;

import 'domain/usecases/recognize_ark_address_usecase.dart';
import 'presentation/send_ark_cubit.dart';
import 'domain/usecases/prepare_internal_recipient_usecase.dart';

import 'package:bb_mobile/features/send/domain/usecases/retry_payjoin_proposal_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_wallet_revisions_usecase.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_send_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/public/send_facade.dart';
import 'package:labels/labels.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/load_send_network_fees_usecase.dart';
import 'package:preferences/preferences.dart';
import 'package:swaps/swaps.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:bb_mobile/features/send/data/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/features/send/data/liquid_wallet_repository.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/coins/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/features/consolidation/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/verify_signed_tx_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:transactions/transactions.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_pset_size_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_send_cross_chain_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_exchange_rate_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_payjoin_original_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_visible_payjoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_adoptable_payjoin_sender_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/verify_exchange_payin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_swap_quote_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_boltz_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_swap_route_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_cross_chain_quote_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/validate_bitcoin_selection_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_presets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/resolve_lightning_address_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/resolve_selected_inputs_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/select_best_wallet_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/verify_send_signed_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/update_send_swap_payin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/validate_coin_control_payment_request_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/send_mode.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_sp_payment_for_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/refresh_sp_wallet_for_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/send_sp_payment_for_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_sp_network_for_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/validate_sp_amount_for_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/validate_sp_recipient_for_send_usecase.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:get_it/get_it.dart';
import 'package:bb_mobile/features/send/domain/usecases/load_send_label_suggestions_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/store_send_transaction_label_usecase.dart';

class SendLocator {
  static void setup(GetIt locator) {
    registerUsecases(locator);
    registerBlocs(locator);
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<PrepareSendBitcoinTransactionUsecase>(
      () => PrepareSendBitcoinTransactionUsecase(
        locator<PrepareBitcoinSendUsecase>(),
      ),
    );
    locator.registerFactory<VerifySignedTxUsecase>(VerifySignedTxUsecase.new);
    locator.registerFactory<SendWithPayjoinUsecase>(
      () => SendWithPayjoinUsecase(locator<PayjoinSender>()),
    );
    locator.registerFactory<RetryPayjoinProposalUsecase>(
      () => RetryPayjoinProposalUsecase(locator<PayjoinSender>()),
    );
    locator.registerFactory<WatchPayjoinUsecase>(
      () => WatchPayjoinUsecase(locator<PayjoinSessions>()),
    );
    locator.registerFactory<GetAdoptablePayjoinSenderUsecase>(
      () => GetAdoptablePayjoinSenderUsecase(locator<PayjoinSessions>()),
    );
    locator.registerFactory<BroadcastPayjoinOriginalUsecase>(
      () => BroadcastPayjoinOriginalUsecase(locator<PayjoinSender>()),
    );
    locator.registerFactory<GetVisiblePayjoinTransactionUsecase>(
      () => GetVisiblePayjoinTransactionUsecase(locator<PayjoinSessions>()),
    );
    locator.registerFactory<DetectBitcoinStringUsecase>(
      () => DetectBitcoinStringUsecase(settings: locator<Preferences>()),
    );
    locator.registerFactory<PrepareBitcoinSendUsecase>(
      () => PrepareBitcoinSendUsecase(
        payjoinSessions: locator<PayjoinSessions>(),
        walletUtxoRepository: locator<WalletUtxoRepository>(),
        bitcoinWalletRepository: locator<BitcoinWalletRepository>(),
      ),
    );
    locator.registerFactory<ValidateBitcoinSelectionUsecase>(
      () => ValidateBitcoinSelectionUsecase(
        payjoinSessions: locator<PayjoinSessions>(),
        walletUtxoRepository: locator<WalletUtxoRepository>(),
      ),
    );
    locator.registerFactory<PrepareLiquidSendUsecase>(
      () => PrepareLiquidSendUsecase(
        liquidWalletRepository: locator<LiquidWalletRepository>(),
      ),
    );
    locator.registerFactory<SignLiquidTxUsecase>(
      () => SignLiquidTxUsecase(
        liquidWalletRepository: locator<LiquidWalletRepository>(),
      ),
    );
    locator.registerFactory<SignBitcoinTxUsecase>(
      () => SignBitcoinTxUsecase(
        bitcoinWalletRepository: locator<BitcoinWalletRepository>(),
      ),
    );
    locator.registerFactory<CreateSendSwapUsecase>(
      () => CreateSendSwapUsecase(
        locator<SwapFacade>(),
        getWalletUsecase: locator<GetWalletUsecase>(),
        getReceiveAddressUsecase: locator<GetReceiveAddressUsecase>(),
      ),
    );
    locator.registerFactory<GetSendSwapQuoteUsecase>(
      () => GetSendSwapQuoteUsecase(locator<SwapFacade>()),
    );
    locator.registerFactory<GetSendSwapRouteUsecase>(
      () => GetSendSwapRouteUsecase(locator<SwapFacade>()),
    );
    locator.registerFactory<CreateBoltzSendSwapUsecase>(
      () => CreateBoltzSendSwapUsecase(
        locator<BoltzSwaps>(),
        locator<SwapWatcher>(),
      ),
    );
    locator.registerFactory<CreateSendCrossChainSwapUsecase>(
      () => CreateSendCrossChainSwapUsecase(
        locator<SwapFacade>(),
        getWalletUsecase: locator<GetWalletUsecase>(),
        getReceiveAddressUsecase: locator<GetReceiveAddressUsecase>(),
      ),
    );
    locator.registerFactory<GetSendCrossChainQuoteUsecase>(
      () => GetSendCrossChainQuoteUsecase(locator<SwapFacade>()),
    );
    locator.registerFactory<ResolveLightningAddressUsecase>(
      ResolveLightningAddressUsecase.new,
    );
    locator.registerFactory<UpdateSendSwapPayinUsecase>(
      () => UpdateSendSwapPayinUsecase(locator<SwapFacade>()),
    );
    locator.registerFactory<WatchSendSwapUsecase>(
      () => WatchSendSwapUsecase(locator<SwapFacade>()),
    );
    locator.registerFactory<SelectBestWalletUsecase>(
      () => SelectBestWalletUsecase(),
    );
    locator.registerFactory<CalculateBitcoinAbsoluteFeesUsecase>(
      () => CalculateBitcoinAbsoluteFeesUsecase(
        bitcoinWalletRepository: locator<BitcoinWalletRepository>(),
      ),
    );
    locator.registerFactory<CalculateLiquidAbsoluteFeesUsecase>(
      () => CalculateLiquidAbsoluteFeesUsecase(
        liquidWalletRepository: locator<LiquidWalletRepository>(),
      ),
    );
    locator.registerFactory<CalculateLiquidPsetSizeUsecase>(
      () => CalculateLiquidPsetSizeUsecase(
        liquidWalletRepository: locator<LiquidWalletRepository>(),
      ),
    );
    locator.registerFactory<PreviewBitcoinFeeUsecase>(
      () => PreviewBitcoinFeeUsecase(
        prepareBitcoinSendUsecase: locator<PrepareBitcoinSendUsecase>(),
        calculateBitcoinAbsoluteFeesUsecase:
            locator<CalculateBitcoinAbsoluteFeesUsecase>(),
      ),
    );
    locator.registerFactory<PreviewBitcoinFeePresetsUsecase>(
      () => PreviewBitcoinFeePresetsUsecase(
        previewBitcoinFeeUsecase: locator<PreviewBitcoinFeeUsecase>(),
      ),
    );
    locator.registerFactory<ValidateSpRecipientForSendUsecase>(
      () => ValidateSpRecipientForSendUsecase(locator<SpFacade>()),
    );
    locator.registerFactory<ValidateSpAmountForSendUsecase>(
      () => ValidateSpAmountForSendUsecase(locator<SpFacade>()),
    );
    locator.registerFactory<GetSpNetworkForSendUsecase>(
      () => GetSpNetworkForSendUsecase(locator<SpFacade>()),
    );
    locator.registerFactory<PrepareSpPaymentForSendUsecase>(
      () => PrepareSpPaymentForSendUsecase(locator<SpFacade>()),
    );
    locator.registerFactory<RefreshSpWalletForSendUsecase>(
      () => RefreshSpWalletForSendUsecase(
        locator<SpFacade>(),
        locator<GetSpNetworkForSendUsecase>(),
      ),
    );
    locator.registerFactory<SendSpPaymentForSendUsecase>(
      () => SendSpPaymentForSendUsecase(locator<SpFacade>()),
    );
    locator.registerFactory<VerifyChainSwapAmountSendUsecase>(
      () => VerifyChainSwapAmountSendUsecase(
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<VerifyExchangePayinUsecase>(
      () => VerifyExchangePayinUsecase(locator<WalletRepository>()),
    );
    locator.registerFactory<GetSendPayjoinEnabledUsecase>(
      () => GetSendPayjoinEnabledUsecase(locator<PayjoinPolicyAccess>()),
    );
    locator.registerFactory<VerifySendSignedTxUsecase>(
      () => VerifySendSignedTxUsecase(locator<VerifySignedTxUsecase>()),
    );
    locator.registerFactory<ResolveSelectedInputsUsecase>(
      () => ResolveSelectedInputsUsecase(locator<PayjoinSessions>()),
    );
    locator.registerFactory<ValidateCoinControlPaymentRequestUsecase>(
      ValidateCoinControlPaymentRequestUsecase.new,
    );
    locator.registerFactory<GetSendExchangeRateUsecase>(
      () => GetSendExchangeRateUsecase(
        getSettingsUsecase: locator<Preferences>(),
        getIndexPrice: Pricer.getIndexPrice,
      ),
    );
  }

  static void registerBlocs(GetIt locator) {
    locator.registerFactory<SendArkCubit>(
      () => SendArkCubit(
        locator.isRegistered<ArkFacade>()
            ? RecognizeArkAddressUsecase(locator<ArkFacade>())
            : null,
      ),
    );
    locator.registerFactoryParam<
      SendCubit,
      Wallet?,
      ({SendRouteArgs? args, String? spWalletLabel})?
    >(
      (wallet, options) => SendCubit(
        prepareInternalRecipientUsecase: PrepareInternalRecipientUsecase(
          locator<WalletFacade>(),
        ),
        watchWalletRevisionsUsecase: WatchWalletRevisionsUsecase(
          locator<WalletFacade>(),
        ),
        wallet: wallet,
        mode: switch (options?.spWalletLabel) {
          final label? => SendModeSp(walletLabel: label),
          null => const SendModeBitcoin(),
        },
        initialSweepOutpoints: switch (options?.args) {
          final args? when args.isSweep => args.selectedOutpoints,
          _ => const {},
        },
        initialSelectedOutpoints: switch (options?.args) {
          final args? when !args.isSweep => args.selectedOutpoints,
          _ => const {},
        },
        loadSendLabelSuggestions: LoadSendLabelSuggestionsUsecase(
          locator<Labels>(),
        ),
        storeSendTransactionLabel: StoreSendTransactionLabelUsecase(
          locator<Labels>(),
        ),
        bestWalletUsecase: locator<SelectBestWalletUsecase>(),
        detectBitcoinStringUsecase: locator<DetectBitcoinStringUsecase>(),
        loadPreferencesUsecase: LoadSendDisplayPreferencesUsecase(
          locator<Preferences>(),
        ),
        getSendExchangeRateUsecase: locator<GetSendExchangeRateUsecase>(),
        getSendAmountQuotesUsecase: GetSendAmountQuotesUsecase(
          settings: locator<Preferences>(),
          read: Pricer.getIndexPrices,
        ),
        loadNetworkFeesUsecase: LoadSendNetworkFeesUsecase(fees: locator()),
        getWalletUtxosUsecase: locator<GetWalletUtxosUsecase>(),
        prepareBitcoinSendUsecase:
            locator<PrepareSendBitcoinTransactionUsecase>(),
        validateBitcoinSelectionUsecase:
            locator<ValidateBitcoinSelectionUsecase>(),
        prepareLiquidSendUsecase: locator<PrepareLiquidSendUsecase>(),
        signBitcoinTxUsecase: locator<SignBitcoinTxUsecase>(),
        signLiquidTxUsecase: locator<SignLiquidTxUsecase>(),
        broadcastBitcoinTxUsecase:
            locator<BroadcastBitcoinTransactionUsecase>(),
        broadcastLiquidTxUsecase: locator<BroadcastLiquidTransactionUsecase>(),
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        getWalletUsecase: locator<GetWalletUsecase>(),
        createSendSwapUsecase: locator<CreateSendSwapUsecase>(),
        getSendSwapQuoteUsecase: locator<GetSendSwapQuoteUsecase>(),
        createSendCrossChainSwapUsecase:
            locator<CreateSendCrossChainSwapUsecase>(),
        getSendCrossChainQuoteUsecase: locator<GetSendCrossChainQuoteUsecase>(),
        resolveLightningAddressUsecase:
            locator<ResolveLightningAddressUsecase>(),
        updateSendSwapPayinUsecase: locator<UpdateSendSwapPayinUsecase>(),
        watchSendSwapUsecase: locator<WatchSendSwapUsecase>(),
        sendWithPayjoinUsecase: locator<SendWithPayjoinUsecase>(),
        watchPayjoinUsecase: locator<WatchPayjoinUsecase>(),
        getAdoptablePayjoinSenderUsecase:
            locator<GetAdoptablePayjoinSenderUsecase>(),
        broadcastPayjoinOriginalUsecase:
            locator<BroadcastPayjoinOriginalUsecase>(),
        getVisiblePayjoinTransactionUsecase:
            locator<GetVisiblePayjoinTransactionUsecase>(),
        retryPayjoinProposalUsecase: locator<RetryPayjoinProposalUsecase>(),
        watchFinishedWalletSyncsUsecase:
            locator<WatchFinishedWalletSyncsUsecase>(),
        calculateLiquidAbsoluteFeesUsecase:
            locator<CalculateLiquidAbsoluteFeesUsecase>(),
        calculateLiquidPsetSizeUsecase:
            locator<CalculateLiquidPsetSizeUsecase>(),
        transactions: locator<Transactions>(),
        calculateBitcoinAbsoluteFeesUsecase:
            locator<CalculateBitcoinAbsoluteFeesUsecase>(),
        verifyChainSwapAmountSendUsecase:
            locator<VerifyChainSwapAmountSendUsecase>(),
        verifyExchangePayinUsecase: locator<VerifyExchangePayinUsecase>(),
        previewBitcoinFeeUsecase: locator<PreviewBitcoinFeeUsecase>(),
        previewBitcoinFeePresetsUsecase:
            locator<PreviewBitcoinFeePresetsUsecase>(),
        checkLiquidConsolidationUsecase:
            locator<CheckLiquidConsolidationUsecase>(),
        getSendPayjoinEnabledUsecase: locator<GetSendPayjoinEnabledUsecase>(),
        verifySignedTxUsecase: locator<VerifySendSignedTxUsecase>(),
        validateSpRecipientForSendUsecase:
            locator<ValidateSpRecipientForSendUsecase>(),
        validateSpAmountForSendUsecase:
            locator<ValidateSpAmountForSendUsecase>(),
        getSpNetworkForSendUsecase: locator<GetSpNetworkForSendUsecase>(),
        prepareSpPaymentForSendUsecase:
            locator<PrepareSpPaymentForSendUsecase>(),
        sendSpPaymentForSendUsecase: locator<SendSpPaymentForSendUsecase>(),
        refreshSpWalletForSendUsecase: locator<RefreshSpWalletForSendUsecase>(),
        resolveSelectedInputsUsecase: locator<ResolveSelectedInputsUsecase>(),
        validateCoinControlPaymentRequestUsecase:
            locator<ValidateCoinControlPaymentRequestUsecase>(),
        getSendSwapRouteUsecase: locator<GetSendSwapRouteUsecase>(),
        createBoltzSendSwapUsecase: locator<CreateBoltzSendSwapUsecase>(),
        recordSwapLockupUsecase: locator<RecordSwapLockupUsecase>(),
        recordPendingSwapLockupUsecase:
            locator<RecordPendingSwapLockupUsecase>(),
        dropPendingSwapLockupUsecase: locator<DropPendingSwapLockupUsecase>(),
        getSwapLimitsAndFeesUsecase: locator<GetSwapLimitsAndFeesUsecase>(),
        createBitcoinToLiquidSwapUsecase:
            locator<CreateBitcoinToLiquidSwapUsecase>(),
        createLiquidToBitcoinSwapUsecase:
            locator<CreateLiquidToBitcoinSwapUsecase>(),
        watchSwapUsecase: locator<WatchSwapUsecase>(),
      ),
    );
  }
}
