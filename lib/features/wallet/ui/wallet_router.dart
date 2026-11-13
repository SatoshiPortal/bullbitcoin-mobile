import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/exchange_access/public/exchange_access_facade.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_wallet_quick_actions_usecase.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:flutter/widgets.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/screens/wallet_detail_screen.dart';
import 'package:bb_mobile/features/wallet/ui/screens/wallet_home_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum WalletRoute {
  walletHome('/wallet'),
  walletDetail('/wallet/:walletId');

  const WalletRoute(this.path);

  final String path;
}

class WalletRouter {
  static GoRoute walletHomeRoute({
    required QuickActionsFacade quickActions,
    required ExchangeAccessFacade exchangeAccess,
    required bool Function(BuildContext) platformAllowsExchange,
    required void Function(BuildContext, QuickAction) onQuickAction,
    required void Function(BuildContext, Set<QuickAction>, List<QuickAction>)
    onCustomizeQuickActions,
  }) => GoRoute(
    name: WalletRoute.walletHome.name,
    path: WalletRoute.walletHome.path,
    pageBuilder: (context, state) {
      return NoTransitionPage(
        key: state.pageKey,
        child: BlocListener<WalletBloc, WalletState>(
          listenWhen: (previous, current) =>
              !previous.noWalletsFound && current.noWalletsFound,
          listener: (context, state) {
            // If no wallets are found, redirect to the onboarding screen
            //  to allow the user to create or restore a wallet.
            context.goNamed(OnboardingRoute.onboarding.name);
          },
          child: WalletHomeScreen(
            quickActions: quickActions,
            platformAllowsExchange: platformAllowsExchange,
            quickActionsPolicy: WatchWalletQuickActionsUsecase(exchangeAccess),
            onQuickAction: onQuickAction,
            onCustomizeQuickActions: onCustomizeQuickActions,
          ),
        ),
      );
    },
  );

  static GoRoute walletDetailRoute({
    required Future<void> Function(BuildContext context, Wallet wallet)
    onOpenCoins,
  }) => GoRoute(
    name: WalletRoute.walletDetail.name,
    path: WalletRoute.walletDetail.path,
    builder: (context, state) {
      final walletId = state.pathParameters['walletId'];
      if (walletId == null) {
        return const SizedBox.shrink();
      }
      return WalletDetailScreen(walletId: walletId, onOpenCoins: onOpenCoins);
    },
  );
}
