import 'package:bb_mobile/core/ark/errors.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/ark/presentation/cubit.dart';
import 'package:bb_mobile/features/ark/ui/ark_wallet_detail_page.dart';
import 'package:bb_mobile/features/ark/ui/receive_page.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ArkRoute {
  arkWalletDetail('/ark-wallet-detail'),
  arkReceive('/ark-receive');

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
        create: (context) => ArkCubit(wallet: wallet)..refresh(),
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
        name: ArkRoute.arkReceive.name,
        path: ArkRoute.arkReceive.path,
        builder: (context, state) => const ReceivePage(),
      ),
    ],
  );
}
