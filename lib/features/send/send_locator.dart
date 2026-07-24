import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/create_chain_swap_to_external_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/decode_invoice_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/update_send_swap_lockup_fees_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_pset_size_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_presets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/select_best_wallet_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/update_paid_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:get_it/get_it.dart';

class SendLocator {
  static void setup(GetIt locator) {
    registerUsecases(locator);
    registerBlocs(locator);
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<DetectBitcoinStringUsecase>(
      () => DetectBitcoinStringUsecase(),
    );
    locator.registerFactory<PrepareBitcoinSendUsecase>(
      () => PrepareBitcoinSendUsecase(
        payjoinRepository: locator<PayjoinRepository>(),
        walletUtxoRepository: locator<WalletUtxoRepository>(),
        bitcoinWalletRepository: locator<BitcoinWalletRepository>(),
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
        swapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<UpdatePaidSendSwapUsecase>(
      () => UpdatePaidSendSwapUsecase(
        swapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
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
    locator.registerFactory<CreateChainSwapToExternalUsecase>(
      () => CreateChainSwapToExternalUsecase(
        walletRepository: locator<WalletRepository>(),
        swapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );
    locator.registerFactory<UpdateSendSwapLockupFeesUsecase>(
      () => UpdateSendSwapLockupFeesUsecase(
        swapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );
    locator.registerFactory<VerifyChainSwapAmountSendUsecase>(
      () => VerifyChainSwapAmountSendUsecase(
        walletRepository: locator<WalletRepository>(),
      ),
    );
  }

  static void registerBlocs(GetIt locator) {
    locator.registerFactoryParam<SendCubit, Wallet?, void>(
      (wallet, _) => SendCubit(
        wallet: wallet,
        labelsFacade: locator<LabelsFacade>(),
        bestWalletUsecase: locator<SelectBestWalletUsecase>(),
        detectBitcoinStringUsecase: locator<DetectBitcoinStringUsecase>(),
        getSettingsUsecase: locator<GetSettingsUsecase>(),
        convertSatsToCurrencyAmountUsecase:
            locator<ConvertSatsToCurrencyAmountUsecase>(),
        getNetworkFeesUsecase: locator<GetNetworkFeesUsecase>(),
        getAvailableCurrenciesUsecase: locator<GetAvailableCurrenciesUsecase>(),
        getWalletUtxosUsecase: locator<GetWalletUtxosUsecase>(),
        prepareBitcoinSendUsecase: locator<PrepareBitcoinSendUsecase>(),
        prepareLiquidSendUsecase: locator<PrepareLiquidSendUsecase>(),
        signBitcoinTxUsecase: locator<SignBitcoinTxUsecase>(),
        signLiquidTxUsecase: locator<SignLiquidTxUsecase>(),
        broadcastBitcoinTxUsecase:
            locator<BroadcastBitcoinTransactionUsecase>(),
        broadcastLiquidTxUsecase: locator<BroadcastLiquidTransactionUsecase>(),
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        getWalletUsecase: locator<GetWalletUsecase>(),
        createSendSwapUsecase: locator<CreateSendSwapUsecase>(),
        updatePaidSendSwapUsecase: locator<UpdatePaidSendSwapUsecase>(),
        getSwapLimitsUsecase: locator<GetSwapLimitsUsecase>(),
        watchSwapUsecase: locator<WatchSwapUsecase>(),
        sendWithPayjoinUsecase: locator<SendWithPayjoinUsecase>(),
        watchPayjoinUsecase: locator<WatchPayjoinUsecase>(),
        watchFinishedWalletSyncsUsecase:
            locator<WatchFinishedWalletSyncsUsecase>(),
        decodeInvoiceUsecase: locator<DecodeInvoiceUsecase>(),
        calculateLiquidAbsoluteFeesUsecase:
            locator<CalculateLiquidAbsoluteFeesUsecase>(),
        calculateLiquidPsetSizeUsecase:
            locator<CalculateLiquidPsetSizeUsecase>(),
        createChainSwapToExternalUsecase:
            locator<CreateChainSwapToExternalUsecase>(),
        watchWalletTransactionByTxIdUsecase:
            locator<WatchWalletTransactionByTxIdUsecase>(),
        calculateBitcoinAbsoluteFeesUsecase:
            locator<CalculateBitcoinAbsoluteFeesUsecase>(),
        updateSendSwapLockupFeesUsecase:
            locator<UpdateSendSwapLockupFeesUsecase>(),
        verifyChainSwapAmountSendUsecase:
            locator<VerifyChainSwapAmountSendUsecase>(),
        previewBitcoinFeeUsecase: locator<PreviewBitcoinFeeUsecase>(),
        previewBitcoinFeePresetsUsecase:
            locator<PreviewBitcoinFeePresetsUsecase>(),
        checkLiquidConsolidationUsecase:
            locator<CheckLiquidConsolidationUsecase>(),
      ),
    );
  }
}
