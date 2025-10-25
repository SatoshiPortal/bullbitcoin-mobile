import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/spark/errors.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/spark/presentation/cubit.dart';
import 'package:bb_mobile/features/spark/ui/receive_page.dart';
import 'package:bb_mobile/features/spark/ui/send_page.dart';
import 'package:bb_mobile/features/spark/ui/spark_about_page.dart';
import 'package:bb_mobile/features/spark/ui/spark_payment_details_page.dart';
import 'package:bb_mobile/features/spark/ui/spark_wallet_detail_page.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/locator.dart';
import 'package:breez_sdk_spark_flutter/breez_sdk_spark.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum SparkRoute {
  sparkWalletDetail('/spark-wallet-detail'),
  sparkAbout('/spark-about'),
  sparkPaymentDetails('/spark-payment-details'),
  sparkReceive('/spark-receive'),
  sparkSend('/spark-send');

  final String path;

  const SparkRoute(this.path);
}

class SparkRouter {
  static final route = ShellRoute(
    builder: (context, state, child) {
      final wallet = context.watch<WalletBloc>().state.sparkWallet;

      if (wallet == null) {
        log.severe('Spark needs a spark wallet initialized');
        throw SparkWalletIsNotInitializedError();
      }

      return BlocProvider(
        create:
            (context) => SparkCubit(
              wallet: wallet,
              convertSatsToCurrencyAmountUsecase:
                  locator<ConvertSatsToCurrencyAmountUsecase>(),
              getAvailableCurrenciesUsecase:
                  locator<GetAvailableCurrenciesUsecase>(),
              walletBloc: context.read<WalletBloc>(),
            )..load(),
        child: child,
      );
    },
    routes: [
      GoRoute(
        name: SparkRoute.sparkWalletDetail.name,
        path: SparkRoute.sparkWalletDetail.path,
        builder: (context, state) => const SparkWalletDetailPage(),
      ),
      GoRoute(
        name: SparkRoute.sparkAbout.name,
        path: SparkRoute.sparkAbout.path,
        builder: (context, state) => const SparkAboutPage(),
      ),
      GoRoute(
        name: SparkRoute.sparkPaymentDetails.name,
        path: SparkRoute.sparkPaymentDetails.path,
        builder: (context, state) {
          final payment = state.extra! as Payment;
          return SparkPaymentDetailsPage(payment: payment);
        },
      ),
      GoRoute(
        name: SparkRoute.sparkReceive.name,
        path: SparkRoute.sparkReceive.path,
        builder: (context, state) => const ReceivePage(),
      ),
      GoRoute(
        name: SparkRoute.sparkSend.name,
        path: SparkRoute.sparkSend.path,
        builder: (context, state) => const SendPage(),
      ),
    ],
  );
}
