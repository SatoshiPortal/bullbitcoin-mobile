import 'package:ark_wallet/ark_wallet.dart';
import 'package:bb_mobile/core/ark/errors.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/ark/presentation/cubit.dart';
import 'package:bb_mobile/features/ark/ui/page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ArkRoute {
  arkHome('/ark/home');

  final String path;

  const ArkRoute(this.path);
}

class ArkRouter {
  static final route = GoRoute(
    name: ArkRoute.arkHome.name,
    path: ArkRoute.arkHome.path,
    builder: (context, state) {
      final wallet = state.extra as ArkWallet?;

      if (wallet == null) {
        final logMessage =
            '${ArkRoute.arkHome.name} can only be accessed with ark wallet as extra';
        log.severe(logMessage);
        throw ArkWalletIsNotInitializedError();
      }

      return BlocProvider(
        create: (context) => ArkCubit(wallet: wallet),
        child: const ArkPage(),
      );
    },
  );
}
