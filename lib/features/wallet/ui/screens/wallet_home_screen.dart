import 'package:onboarding/setup.dart' show OnboardingFeature;
import 'package:provisioning/provisioning.dart' show NetworkWalletProvisioning;
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_consolidation.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_errors.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_bottom_buttons.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_cards.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' as wallet_model;
import 'package:bull_ark/ark_ui.dart' show ArkHomeCard;
import 'package:bull_ui/app_theme.dart';
import 'package:primitives/primitives.dart' show NetworkCapability;
import 'package:settings/settings.dart'
    show NetworkCapabilityVisibility, Settings;
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bitcoin_price/bitcoin_price.dart'
    show BitcoinPriceFeature, PriceChartWidget;
import 'package:bull_ark/ark_foreground_setup.dart';
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
      header: _WalletHomeHeader(
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
      ark: _arkCard,
      bottomActions: WalletBottomButtons(),
    );
  }

  Widget _arkCard(int refresh) {
    final host = arkHost;
    if (host == null) return const SizedBox.shrink();
    return Builder(
      builder: (context) {
        final scope = context.select(
          (WalletBloc bloc) => bloc.state.wallets
              .where(
                (wallet) =>
                    wallet.isDefault &&
                    wallet.network == wallet_model.Network.bitcoinRegtest,
              )
              .map((wallet) => (wallet.id, wallet.masterFingerprint))
              .toList()
              .toString(),
        );
        return NetworkCapabilityVisibility(
          capability: NetworkCapability.ark,
          child: ArkHomeCard(
            key: ValueKey(scope),
            host: host,
            refresh: refresh,
            scope: scope,
            buildCard:
                (
                  context, {
                  required title,
                  required description,
                  required balanceSat,
                  required isSyncing,
                  required onTap,
                }) => WalletCard(
                  tagColor: context.appColors.bitcoinOrange,
                  title: title,
                  description: description,
                  balanceSat: balanceSat,
                  isSyncing: isSyncing,
                  onTap: onTap,
                ),
          ),
        );
      },
    );
  }
}

class _WalletHomeHeader extends StatelessWidget {
  final Widget actions;

  const _WalletHomeHeader({required this.actions});

  @override
  Widget build(BuildContext context) {
    final display = context.select((WalletBloc bloc) {
      final state = bloc.state;
      return (
        totalSat: state.totalBalance(),
        isLoading:
            state.status == WalletStatus.initial ||
            state.status == WalletStatus.loading,
        hideAmounts: state.amountDisplay?.hideAmounts,
      );
    });
    return WalletHomeTopSection(
      actions: actions,
      background: AssetImage(Assets.backgrounds.bgRed.path),
      totalSat: display.totalSat,
      isLoading: display.isLoading,
      hideAmounts: display.hideAmounts,
      unavailableLabel: context.loc.walletLoadFailed,
      onCurrencyChanged: Settings.changeDisplayCurrency,
      showChart: BitcoinPriceFeature.watchChartVisible(context),
      chart: const PriceChartWidget(),
      onCloseChart: () => BitcoinPriceFeature.hideChart(context),
      closeChartLabel: MaterialLocalizations.of(context).backButtonTooltip,
    );
  }
}
