import 'package:bb_mobile/core/spark/usecases/enable_spark_usecase.dart';
import 'package:bb_mobile/core/spark/usecases/get_spark_wallet_usecase.dart';
import 'package:bb_mobile/features/spark_setup/presentation/cubit.dart';
import 'package:bb_mobile/features/spark_setup/setup_page.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum SparkSetupRoute {
  sparkSetup('/spark/setup');

  final String path;

  const SparkSetupRoute(this.path);
}

class SparkSetupRouter {
  static final route = GoRoute(
    name: SparkSetupRoute.sparkSetup.name,
    path: SparkSetupRoute.sparkSetup.path,
    builder: (context, state) {
      final wallet = context.watch<WalletBloc>().state.sparkWallet;

      return BlocProvider(
        create:
            (context) => SparkSetupCubit(
              enableSparkUsecase: locator<EnableSparkUsecase>(),
              getSparkWalletUsecase: locator<GetSparkWalletUsecase>(),
              wallet: wallet,
              walletBloc: context.read<WalletBloc>(),
            ),
        child: BlocListener<WalletBloc, WalletState>(
          listenWhen:
              (previous, current) =>
                  previous.sparkWallet == null && current.sparkWallet != null,
          listener: (context, state) {
            context.goNamed(WalletRoute.walletHome.name);
          },
          child: const SparkSetupPage(),
        ),
      );
    },
  );
}
