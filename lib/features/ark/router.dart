import 'package:ark_wallet/ark_wallet.dart' as ark_wallet;
import 'package:bb_mobile/core/ark/errors.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/ark/presentation/cubit.dart';
import 'package:bb_mobile/features/ark/ui/ark_about_page.dart';
import 'package:bb_mobile/features/ark/ui/ark_transaction_details_page.dart';
import 'package:bb_mobile/features/ark/ui/ark_wallet_detail_page.dart';
import 'package:bb_mobile/features/ark/ui/receive_page.dart';
import 'package:bb_mobile/features/ark/ui/send_page.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ArkRoute {
  arkWalletDetail('/ark-wallet-detail'),
  arkAbout('/ark-about'),
  arkTransactionDetails('/ark-transaction-details'),
  arkReceive('/ark-receive'),
  arkSend('/ark-send');

  final String path;

  const ArkRoute(this.path);
}

class ArkRouter {
  static final route = ShellRoute(
    builder: (context, state, child) {
      final wallet = context.watch<WalletBloc>().state.arkWallet;

      if (wallet == null) {
        log.severe('Ark needs an ark wallet initialized');
        throw ArkWalletIsNotInitializedError();
      }

      return BlocProvider(
        create:
            (context) =>
                ArkCubit(
                    wallet: wallet,
                    convertSatsToCurrencyAmountUsecase:
                        locator<ConvertSatsToCurrencyAmountUsecase>(),
                    getAvailableCurrenciesUsecase:
                        locator<GetAvailableCurrenciesUsecase>(),
                    walletBloc: context.read<WalletBloc>(),
                  )
                  ..loadTransactions()
                  ..loadCurrencies()
                  ..loadExchangeRate()
                  ..loadBalance(),

        child: child,
      );
    },
    routes: [
      GoRoute(
        name: ArkRoute.arkWalletDetail.name,
        path: ArkRoute.arkWalletDetail.path,
        builder: (context, state) => const ArkWalletDetailPage(),
      ),
      GoRoute(
        name: ArkRoute.arkAbout.name,
        path: ArkRoute.arkAbout.path,
        builder: (context, state) => const ArkAboutPage(),
      ),
      GoRoute(
        name: ArkRoute.arkTransactionDetails.name,
        path: ArkRoute.arkTransactionDetails.path,
        builder: (context, state) {
          final transaction = state.extra! as ark_wallet.Transaction;
          return ArkTransactionDetailsPage(transaction: transaction);
        },
      ),
      GoRoute(
        name: ArkRoute.arkReceive.name,
        path: ArkRoute.arkReceive.path,
        builder: (context, state) => const ReceivePage(),
      ),
      GoRoute(
        name: ArkRoute.arkSend.name,
        path: ArkRoute.arkSend.path,
        builder: (context, state) => const SendPage(),
      ),
    ],
  );
}
