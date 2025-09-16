import 'package:bb_mobile/core/ark/entities/ark_wallet.dart';
import 'package:bb_mobile/core/ark/errors.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/ark/presentation/cubit.dart';
import 'package:bb_mobile/features/ark/ui/ark_wallet_detail_page.dart';
import 'package:bb_mobile/features/ark/ui/receive_page.dart';
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
      final wallet = state.extra as ArkWallet?;

      if (wallet == null) {
        const logMessage = 'Ark can only be accessed with ark wallet as extra';
        log.severe(logMessage);
        throw ArkWalletIsNotInitializedError();
      }

      return BlocProvider(
        create: (context) => ArkCubit(wallet: wallet),
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
