import 'package:send/src/payment/domain/usecases/load_send_display_preferences_usecase.dart';

import 'domain/usecases/get_send_amount_quotes_usecase.dart';

import 'domain/usecases/recognize_ark_address_usecase.dart';
import 'presentation/send_ark_cubit.dart';
import 'domain/usecases/prepare_internal_recipient_usecase.dart';

import 'package:send/src/payment/domain/usecases/retry_payjoin_proposal_usecase.dart';
import 'package:send/src/payment/domain/usecases/watch_wallet_revisions_usecase.dart';
import 'package:send/src/payment/public/send_route_args.dart';
import 'package:send/src/payment/domain/usecases/load_send_network_fees_usecase.dart';
import 'package:swaps/swaps.dart';
import 'package:send/src/payment/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:send/src/payment/domain/usecases/read_send_recipient_amount_usecase.dart';
import 'package:send/send.dart';
import 'package:send/src/payment/domain/usecases/create_send_cross_chain_swap_usecase.dart';
import 'package:send/src/payment/domain/usecases/create_send_swap_usecase.dart';
import 'package:address_view/payment_destination.dart';
import 'package:send/src/payment/domain/usecases/get_send_exchange_rate_usecase.dart';
import 'package:send/src/payment/domain/usecases/broadcast_payjoin_original_usecase.dart';
import 'package:send/src/payment/domain/usecases/get_visible_payjoin_transaction_usecase.dart';
import 'package:send/src/payment/domain/usecases/get_adoptable_payjoin_sender_usecase.dart';
import 'package:send/src/payment/domain/usecases/get_send_payjoin_enabled_usecase.dart';
import 'package:send/src/payment/domain/usecases/verify_exchange_payin_usecase.dart';
import 'package:send/src/payment/domain/usecases/get_send_swap_quote_usecase.dart';
import 'package:send/src/payment/domain/usecases/create_boltz_send_swap_usecase.dart';
import 'package:send/src/payment/domain/usecases/get_send_swap_route_usecase.dart';
import 'package:send/src/payment/domain/usecases/get_send_cross_chain_quote_usecase.dart';
import 'package:send/src/payment/domain/usecases/validate_bitcoin_selection_usecase.dart';
import 'package:send/src/payment/domain/usecases/resolve_lightning_address_usecase.dart';
import 'package:send/src/payment/domain/usecases/resolve_selected_inputs_usecase.dart';
import 'package:send/src/payment/domain/usecases/select_best_wallet_usecase.dart';
import 'package:send/src/payment/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:send/src/payment/domain/usecases/watch_payjoin_usecase.dart';
import 'package:send/src/payment/domain/usecases/update_send_swap_payin_usecase.dart';
import 'package:send/src/payment/domain/usecases/validate_coin_control_payment_request_usecase.dart';
import 'package:send/src/payment/domain/usecases/watch_send_swap_usecase.dart';
import 'package:send/src/payment/presentation/bloc/send_cubit.dart';
import 'package:send/src/payment/presentation/send_mode.dart';
import 'package:send/src/payment/domain/usecases/prepare_sp_payment_for_send_usecase.dart';
import 'package:send/src/payment/domain/usecases/refresh_sp_wallet_for_send_usecase.dart';
import 'package:send/src/payment/domain/usecases/send_sp_payment_for_send_usecase.dart';
import 'package:send/src/payment/domain/usecases/get_sp_network_for_send_usecase.dart';
import 'package:send/src/payment/domain/usecases/validate_sp_amount_for_send_usecase.dart';
import 'package:send/src/payment/domain/usecases/validate_sp_recipient_for_send_usecase.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:spend/spend.dart';
import 'package:send/src/payment/domain/usecases/load_send_label_suggestions_usecase.dart';
import 'package:send/src/payment/domain/usecases/store_send_transaction_label_usecase.dart';

import 'package:fees/fees.dart';
import 'package:preferences/preferences.dart' show ActiveEnvironmentReader;

import 'domain/usecases/load_send_coins_usecase.dart';
import 'domain/usecases/load_send_sources_usecase.dart';
import 'send_payment_dependencies.dart';

(SendCubit, SendArkCubit) createPaymentCubits({
  required SendPaymentDependencies dependencies,
  required SendRouteArgs? args,
  required String? spWalletLabel,
  required Spend spend,
  required Fees fees,
  required ActiveEnvironmentReader environment,
}) {
  final d = dependencies;
  final sources = LoadSendSourcesUsecase(
    d.inventory,
    d.native.loadWallet,
    d.readSignerDevice,
    environment,
    synchronize: d.synchronize,
    finished: d.finishedSyncs,
  );
  final recipientAmount = ReadSendRecipientAmountUsecase(d.inventory, d.native);
  final spNetwork = GetSpNetworkForSendUsecase(d.silent);
  final ark = d.ark;
  return (
    SendCubit(
      walletKey: args?.wallet,
      mode: switch (spWalletLabel) {
        final label? => SendModeSp(walletLabel: label),
        null => const SendModeBitcoin(),
      },
      initialSweepOutpoints: switch (args) {
        final args? when args.isSweep => args.selectedOutpoints,
        _ => const {},
      },
      initialSelectedOutpoints: switch (args) {
        final args? when !args.isSweep => args.selectedOutpoints,
        _ => const {},
      },
      prepareInternalRecipientUsecase: PrepareInternalRecipientUsecase(
        d.receive,
      ),
      watchWalletRevisionsUsecase: WatchWalletRevisionsUsecase(
        d.native.changes,
      ),
      loadSendLabelSuggestions: LoadSendLabelSuggestionsUsecase(d.labels),
      storeSendTransactionLabel: StoreSendTransactionLabelUsecase(d.labels),
      bestWalletUsecase: SelectBestWalletUsecase(),
      detectBitcoinStringUsecase: DetectBitcoinStringUsecase(
        settings: d.preferences,
      ),
      loadPreferencesUsecase: LoadSendDisplayPreferencesUsecase(d.preferences),
      getSendExchangeRateUsecase: GetSendExchangeRateUsecase(
        getSettingsUsecase: d.preferences,
        getIndexPrice: Pricer.getIndexPrice,
      ),
      getSendAmountQuotesUsecase: GetSendAmountQuotesUsecase(
        settings: d.preferences,
        read: Pricer.getIndexPrices,
      ),
      loadNetworkFeesUsecase: LoadSendNetworkFeesUsecase(fees: fees),
      loadCoins: LoadSendCoinsUsecase(d.coins),
      validateBitcoinSelectionUsecase: ValidateBitcoinSelectionUsecase(spend),
      loadSources: sources,
      createSendSwapUsecase: CreateSendSwapUsecase(
        d.orders,
        getWalletUsecase: sources,
        getReceiveAddressUsecase: d.addresses,
      ),
      getSendSwapQuoteUsecase: GetSendSwapQuoteUsecase(d.orders),
      createSendCrossChainSwapUsecase: CreateSendCrossChainSwapUsecase(
        d.orders,
        getWalletUsecase: sources,
        getReceiveAddressUsecase: d.addresses,
      ),
      getSendCrossChainQuoteUsecase: GetSendCrossChainQuoteUsecase(d.orders),
      resolveLightningAddressUsecase: ResolveLightningAddressUsecase(),
      updateSendSwapPayinUsecase: UpdateSendSwapPayinUsecase(d.orders),
      watchSendSwapUsecase: WatchSendSwapUsecase(d.orders),
      sendWithPayjoinUsecase: SendWithPayjoinUsecase(d.payjoin.sender, spend),
      spend: spend,
      watchPayjoinUsecase: WatchPayjoinUsecase(d.payjoin.sessions),
      getAdoptablePayjoinSenderUsecase: GetAdoptablePayjoinSenderUsecase(
        d.payjoin.sessions,
      ),
      broadcastPayjoinOriginalUsecase: BroadcastPayjoinOriginalUsecase(
        d.payjoin.sender,
      ),
      getVisiblePayjoinTransactionUsecase: GetVisiblePayjoinTransactionUsecase(
        d.payjoin.sessions,
      ),
      retryPayjoinProposalUsecase: RetryPayjoinProposalUsecase(
        d.payjoin.sender,
      ),
      transactions: d.transactions,
      verifyChainSwapAmountSendUsecase: VerifyChainSwapAmountSendUsecase(
        recipientAmount: recipientAmount,
      ),
      verifyExchangePayinUsecase: VerifyExchangePayinUsecase(recipientAmount),
      consolidation: Consolidation.open(spend),
      getSendPayjoinEnabledUsecase: GetSendPayjoinEnabledUsecase(
        d.payjoin.policy,
      ),
      validateSpRecipientForSendUsecase: ValidateSpRecipientForSendUsecase(
        d.silent,
      ),
      validateSpAmountForSendUsecase: ValidateSpAmountForSendUsecase(d.silent),
      getSpNetworkForSendUsecase: spNetwork,
      prepareSpPaymentForSendUsecase: PrepareSpPaymentForSendUsecase(d.silent),
      sendSpPaymentForSendUsecase: SendSpPaymentForSendUsecase(d.silent),
      refreshSpWalletForSendUsecase: RefreshSpWalletForSendUsecase(
        d.silent,
        spNetwork,
      ),
      resolveSelectedInputsUsecase: ResolveSelectedInputsUsecase(
        d.payjoin.sessions,
      ),
      validateCoinControlPaymentRequestUsecase:
          ValidateCoinControlPaymentRequestUsecase(),
      getSendSwapRouteUsecase: GetSendSwapRouteUsecase(d.swaps),
      createBoltzSendSwapUsecase: CreateBoltzSendSwapUsecase(
        d.swaps.boltz,
        d.swaps.watcher,
      ),
      recordSwapLockupUsecase: RecordSwapLockupUsecase(
        d.swaps.resolver,
        d.swaps.watcher,
      ),
      recordPendingSwapLockupUsecase: RecordPendingSwapLockupUsecase(
        d.swaps.resolver,
      ),
      dropPendingSwapLockupUsecase: DropPendingSwapLockupUsecase(
        d.swaps.resolver,
      ),
      getSwapLimitsAndFeesUsecase: GetSwapLimitsAndFeesUsecase(d.swaps.boltz),
      createBitcoinToLiquidSwapUsecase: CreateBitcoinToLiquidSwapUsecase(
        d.swaps.boltz,
        d.swaps.watcher,
      ),
      createLiquidToBitcoinSwapUsecase: CreateLiquidToBitcoinSwapUsecase(
        d.swaps.boltz,
        d.swaps.watcher,
      ),
      watchSwapUsecase: WatchSwapUsecase(d.swaps.store),
    ),
    SendArkCubit(ark == null ? null : RecognizeArkAddressUsecase(ark)),
  );
}
