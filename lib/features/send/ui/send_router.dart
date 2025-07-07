import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/create_chain_swap_to_external_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/decode_invoice_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/select_best_wallet_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/update_paid_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/request_identifier/request_identifier_cubit.dart';
import 'package:bb_mobile/features/send/request_identifier/request_identifier_screen.dart';
import 'package:bb_mobile/features/send/ui/screens/send_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum SendRoute {
  send('/send'),
  requestIdentifier('request-identifier');

  const SendRoute(this.path);

  final String path;
}

class SendRouter {
  static final route = GoRoute(
    name: SendRoute.send.name,
    path: SendRoute.send.path,
    builder: (context, state) {
      // Pass a preselected wallet to the send bloc if one is set in the URI
      //  of the incoming route
      if (state.extra is! RequestIdentifierExtra) throw 'Invalid extra';

      final identifierExtra = state.extra! as RequestIdentifierExtra;
      return BlocProvider(
        create:
            (_) =>
                SendCubit(
                    wallet: identifierExtra.wallet,
                    paymentRequest: identifierExtra.request,
                    bestWalletUsecase: locator<SelectBestWalletUsecase>(),
                    detectBitcoinStringUsecase:
                        locator<DetectBitcoinStringUsecase>(),
                    getSettingsUsecase: locator<GetSettingsUsecase>(),
                    convertSatsToCurrencyAmountUsecase:
                        locator<ConvertSatsToCurrencyAmountUsecase>(),
                    getNetworkFeesUsecase: locator<GetNetworkFeesUsecase>(),
                    getWalletUsecase: locator<GetWalletUsecase>(),
                    getWalletsUsecase: locator<GetWalletsUsecase>(),
                    getWalletUtxosUsecase: locator<GetWalletUtxosUsecase>(),
                    getAvailableCurrenciesUsecase:
                        locator<GetAvailableCurrenciesUsecase>(),
                    prepareBitcoinSendUsecase:
                        locator<PrepareBitcoinSendUsecase>(),
                    prepareLiquidSendUsecase:
                        locator<PrepareLiquidSendUsecase>(),
                    sendWithPayjoinUsecase: locator<SendWithPayjoinUsecase>(),
                    createSendSwapUsecase: locator<CreateSendSwapUsecase>(),
                    updatePaidSendSwapUsecase:
                        locator<UpdatePaidSendSwapUsecase>(),
                    getSwapLimitsUsecase: locator<GetSwapLimitsUsecase>(),
                    watchSwapUsecase: locator<WatchSwapUsecase>(),
                    watchFinishedWalletSyncsUsecase:
                        locator<WatchFinishedWalletSyncsUsecase>(),
                    decodeInvoiceUsecase: locator<DecodeInvoiceUsecase>(),
                    signBitcoinTxUsecase: locator<SignBitcoinTxUsecase>(),
                    signLiquidTxUsecase: locator<SignLiquidTxUsecase>(),
                    calculateBitcoinAbsoluteFeesUsecase:
                        locator<CalculateBitcoinAbsoluteFeesUsecase>(),
                    calculateLiquidAbsoluteFeesUsecase:
                        locator<CalculateLiquidAbsoluteFeesUsecase>(),
                    createChainSwapToExternalUsecase:
                        locator<CreateChainSwapToExternalUsecase>(),
                    watchWalletTransactionByTxIdUsecase:
                        locator<WatchWalletTransactionByTxIdUsecase>(),
                    broadcastBitcoinTxUsecase:
                        locator<BroadcastBitcoinTransactionUsecase>(),
                    broadcastLiquidTxUsecase:
                        locator<BroadcastLiquidTransactionUsecase>(),
                  )
                  ..loadWalletWithRatesAndFees()
                  ..processPaymentRequest(),
        child: const SendScreen(),
      );
    },
    routes: [
      GoRoute(
        name: SendRoute.requestIdentifier.name,
        path: SendRoute.requestIdentifier.path,
        builder: (context, state) {
          final wallet = state.extra is Wallet ? state.extra! as Wallet : null;
          return BlocProvider(
            create: (_) => RequestIdentifierCubit(wallet: wallet),
            child: const RequestIdentifierScreen(),
          );
        },
      ),
    ],
  );
}
