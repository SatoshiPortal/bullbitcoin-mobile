import 'package:coins/coins.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bb_mobile/features/wallet/presentation/network_wallet_setup_cubit.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bull_ark/ark_foreground_setup.dart';
import 'package:flutter/widgets.dart';
import 'package:onboarding/onboarding.dart';
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
    required ArkForegroundHost? arkHost,
    required QuickActionsCubit Function() quickActions,
    required void Function(BuildContext, QuickAction) onQuickAction,
    required void Function(BuildContext) onCustomizeQuickActions,
    required ExchangePromptCubit Function() exchangePrompt,
    required void Function(BuildContext) onActivateExchange,
    required int Function(BuildContext) watchUnreadSupportMessages,
    required Widget Function() announcements,
    required NetworkWalletSetupCubit Function() createSetupCubit,
  }) => GoRoute(
    name: WalletRoute.walletHome.name,
    path: WalletRoute.walletHome.path,
    pageBuilder: (context, state) {
      return NoTransitionPage(
        key: state.pageKey,
        child: WalletHomeScreen(
          arkHost: arkHost,
          createSetupCubit: createSetupCubit,
          onEmptyMainnet: () => OnboardingNavigation.go(GoRouter.of(context)),
          onImportNetworkWallet: () =>
              OnboardingNavigation.openPhysicalRecovery(context),
          onRecoverEncryptedVault: () =>
              RecoverBullFeature.open(context, RecoverBullFlow.recoverVault),
          quickActions: quickActions(),
          onQuickAction: onQuickAction,
          onCustomizeQuickActions: onCustomizeQuickActions,
          exchangePrompt: exchangePrompt(),
          onActivateExchange: onActivateExchange,
          watchUnreadSupportMessages: watchUnreadSupportMessages,
          announcements: announcements(),
        ),
      );
    },
  );

  static GoRoute walletDetailRoute({
    required Widget Function(String walletId, Widget child) scopeWalletHistory,
    required Future<void> Function(BuildContext context, Wallet wallet)
    onOpenCoins,
    required Future<Result<CoinSummary, CoinsFailure>> Function(String)
    loadCoinSummary,
  }) => GoRoute(
    name: WalletRoute.walletDetail.name,
    path: WalletRoute.walletDetail.path,
    builder: (context, state) {
      final walletId = state.pathParameters['walletId'];
      if (walletId == null) {
        return const SizedBox.shrink();
      }
      return WalletDetailScreen(
        walletId: walletId,
        onOpenCoins: onOpenCoins,
        loadCoinSummary: loadCoinSummary,
        scopeWalletHistory: scopeWalletHistory,
      );
    },
  );
}
