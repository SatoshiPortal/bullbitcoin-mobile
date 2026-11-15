import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bb_mobile/features/wallet/presentation/network_wallet_setup_cubit.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter/widgets.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/features/wallet/ui/screens/wallet_detail_screen.dart';
import 'package:bb_mobile/features/wallet/ui/screens/wallet_home_screen.dart';
import 'package:go_router/go_router.dart';

enum WalletRoute {
  walletHome('/wallet'),
  walletDetail('/wallet/:walletId');

  const WalletRoute(this.path);

  final String path;
}

class WalletRouter {
  static GoRoute walletHomeRoute({
    required QuickActionsCubit quickActions,
    required void Function(BuildContext, QuickAction) onQuickAction,
    required void Function(BuildContext) onCustomizeQuickActions,
    required NetworkWalletSetupCubit Function() createSetupCubit,
  }) => GoRoute(
    name: WalletRoute.walletHome.name,
    path: WalletRoute.walletHome.path,
    pageBuilder: (context, state) {
      return NoTransitionPage(
        key: state.pageKey,
        child: WalletHomeScreen(
          createSetupCubit: createSetupCubit,
          onEmptyMainnet: () =>
              context.goNamed(OnboardingRoute.onboarding.name),
          onImportNetworkWallet: () =>
              context.pushNamed(OnboardingRoute.recoverFromPhysical.name),
          quickActions: quickActions,
          onQuickAction: onQuickAction,
          onCustomizeQuickActions: onCustomizeQuickActions,
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
