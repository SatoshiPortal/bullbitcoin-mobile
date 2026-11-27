import 'package:onboarding/setup.dart' show OnboardingFeature;
import 'package:provisioning/provisioning.dart' show NetworkWalletProvisioning;
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_consolidation.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_errors.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_bottom_buttons.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_cards.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/ark_dashboard_entry.dart';
import 'package:bull_ark/ark_foreground_setup.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_home_top_section.dart';
import 'package:overview/overview.dart';
import 'package:swap_feature/swap_feature.dart' show HomeOngoingSwaps;
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class WalletHomeScreen extends StatelessWidget {
  final ArkForegroundHost? arkHost;
  final NetworkWalletProvisioning Function() networkWalletProvisioning;
  final VoidCallback onEmptyMainnet;
  final Widget announcements;
  final VoidCallback onImportNetworkWallet;
  final VoidCallback onRecoverEncryptedVault;
  final QuickActionsCubit quickActions;
  final void Function(BuildContext, QuickAction) onQuickAction;
  final void Function(BuildContext) onCustomizeQuickActions;
  final ExchangePromptCubit exchangePrompt;
  final void Function(BuildContext) onActivateExchange;
  final int Function(BuildContext)? watchUnreadSupportMessages;

  const WalletHomeScreen({
    super.key,
    required this.arkHost,
    required this.networkWalletProvisioning,
    required this.onEmptyMainnet,
    required this.announcements,
    required this.onImportNetworkWallet,
    required this.onRecoverEncryptedVault,
    required this.quickActions,
    required this.onQuickAction,
    required this.onCustomizeQuickActions,
    required this.exchangePrompt,
    required this.onActivateExchange,
    this.watchUnreadSupportMessages,
  });

  @override
  Widget build(BuildContext context) {
    final noWallets = context.select(
      (WalletBloc bloc) => bloc.state.noWalletsFound,
    );
    final isRefreshing =
        !noWallets &&
        context.select((WalletBloc bloc) => bloc.state.isRefreshing);
    return OverviewHome(
      homePath: WalletRoute.walletHome.path,
      empty: noWallets
          ? OnboardingFeature.emptyNetworkWallets(
              provisioning: networkWalletProvisioning,
              refreshing: context.read<WalletBloc>().stream.map(
                (state) => state.isRefreshing,
              ),
              initiallyRefreshing: context
                  .read<WalletBloc>()
                  .state
                  .isRefreshing,
              onMainnet: onEmptyMainnet,
              onImport: onImportNetworkWallet,
              onRecoverEncryptedVault: onRecoverEncryptedVault,
              onReady: () =>
                  context.read<WalletBloc>().add(const WalletStarted()),
            )
          : null,
      isRefreshing: isRefreshing,
      refreshVisibleWallets: () {
        context.read<WalletBloc>().add(const RefreshSpWallet());
        context.read<WalletBloc>().add(const WalletRefreshed());
      },
      waitForRefresh: () => context.read<WalletBloc>().waitForRefresh(),
      refreshWallets: () => context.read<WalletBloc>().refresh(),
      headerBackgroundHeight: WalletHomeTopSection.minBackgroundHeight,
      header: WalletHomeTopSection(
        actions: WalletQuickActions(
          quickActions: quickActions,
          onAction: onQuickAction,
          onCustomize: onCustomizeQuickActions,
          exchangePrompt: exchangePrompt,
          onActivateExchange: onActivateExchange,
          unreadSupportMessages: watchUnreadSupportMessages?.call(context) ?? 0,
        ),
      ),
      announcements: announcements,
      warnings: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Builder(
            builder: (context) => HomeOngoingSwaps(
              swaps: context.select(
                (WalletBloc bloc) => bloc.state.ongoingSwaps,
              ),
            ),
          ),
          const HomeWarnings(),
        ],
      ),
      consolidation: const HomeConsolidationBanner(),
      wallets: WalletCards(
        onTap: (wallet) => context.pushNamed(
          WalletRoute.walletDetail.name,
          pathParameters: {'walletId': wallet.id},
        ),
      ),
      ark: (refresh) => ArkDashboardEntry(host: arkHost, refresh: refresh),
      bottomActions: WalletBottomButtons(),
    );
  }
}
