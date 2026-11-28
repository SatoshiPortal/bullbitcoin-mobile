import 'dart:async';

import 'package:backups/backups.dart';
import 'package:bitcoin_price/bitcoin_price.dart';
import 'package:bull_ark/ark_foreground_setup.dart';
import 'package:bull_ark/ark_ui.dart' show ArkHomeCard;
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show BullDisclosureLink;
import 'package:coins/coins.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:network/network.dart';
import 'package:onboarding/onboarding.dart';
import 'package:onboarding/setup.dart' show OnboardingFeature;
import 'package:overview/catalogue.dart';
import 'package:overview/detail.dart';
import 'package:overview/overview.dart';
import 'package:overview/routes.dart';
import 'package:primitives/primitives.dart'
    show LiquidNetwork, NetworkCapability, Result, SignerEntity;
import 'package:secrets/secrets.dart' show WalletSigner;
import 'package:provisioning/provisioning.dart' show NetworkWalletProvisioning;
import 'package:receive/receive.dart';
import 'package:receive/routes.dart';
import 'package:send/send.dart';
import 'package:settings/settings.dart';
import 'package:silent/silent.dart' show SilentNavigation;
import 'package:swap_feature/swap_feature.dart' show SwapNavigation;
import 'package:sync/sync.dart' show WalletKey;
import 'package:transactions/transactions.dart';

import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/locator.dart';
import 'package:go_router/go_router.dart';

/// Composition of Overview's wallet screens with their feature-owned slots.
abstract final class OverviewRouter {
  static GoRoute walletHomeRoute({
    required ArkForegroundHost? arkHost,
    required QuickActionsCubit Function() quickActions,
    required void Function(BuildContext, QuickAction) onQuickAction,
    required void Function(BuildContext) onCustomizeQuickActions,
    required ExchangePromptCubit Function() exchangePrompt,
    required void Function(BuildContext) onActivateExchange,
    required int Function(BuildContext) watchUnreadSupportMessages,
    required Widget Function() announcements,
    required NetworkWalletProvisioning Function() networkWalletProvisioning,
  }) => GoRoute(
    name: WalletRoute.walletHome.name,
    path: WalletRoute.walletHome.path,
    pageBuilder: (context, state) => NoTransitionPage(
      key: state.pageKey,
      child: Builder(
        builder: (context) {
          final home = locator<OverviewHomeController>();
          return OverviewHomeScreen(
            controller: home,
            homePath: WalletRoute.walletHome.path,
            empty: _EmptyNetworkHome(provisioning: networkWalletProvisioning),
            header:
                (
                  context, {
                  required int? totalSat,
                  required bool isLoading,
                  required bool? hideAmounts,
                }) => WalletHomeTopSection(
                  actions: WalletQuickActions(
                    quickActions: quickActions(),
                    onAction: onQuickAction,
                    onCustomize: onCustomizeQuickActions,
                    exchangePrompt: exchangePrompt(),
                    onActivateExchange: onActivateExchange,
                    unreadSupportMessages: watchUnreadSupportMessages(context),
                  ),
                  background: AssetImage(Assets.backgrounds.bgRed.path),
                  totalSat: totalSat,
                  isLoading: isLoading,
                  hideAmounts: hideAmounts,
                  unavailableLabel: context.loc.walletLoadFailed,
                  onCurrencyChanged: Settings.changeDisplayCurrency,
                  showChart: BitcoinPriceFeature.watchChartVisible(context),
                  chart: const PriceChartWidget(),
                  onCloseChart: () => BitcoinPriceFeature.hideChart(context),
                  closeChartLabel: MaterialLocalizations.of(context)
                      .backButtonTooltip,
                ),
            announcements: announcements(),
            consolidation: ValueListenableBuilder<OverviewHomeState>(
              valueListenable: home,
              builder: (context, current, _) => HomeConsolidationBanner(
                consolidation: context.read<Consolidation>(),
                isRefreshing: current.isRefreshing,
                wallets: [
                  for (final row in current.rows)
                    if (row.selection.key.network is LiquidNetwork)
                      (
                        walletId: row.selection.key.id,
                        walletName: _walletName(context, row),
                      ),
                ],
              ),
            ),
            backupWarning: BackupCard(
              icon: AssetImage(Assets.misc.passwordbook.path),
              onTap: () => BackupsNavigation.start(context),
            ),
            walletPickerCopy: _pickerCopy(context),
            warningsCopy: _warningsCopy(context),
            onOpenWallet: (selection) => context.pushNamed(
              WalletRoute.walletDetail.name,
              pathParameters: {'walletId': selection.key.id},
            ),
            onOpenWarning: (destination) => switch (destination) {
              HomeWarningDestination.electrum => NetworkNavigation.open(
                context,
                section: NetworkSection.electrum,
              ),
              HomeWarningDestination.tor => NetworkNavigation.open(
                context,
                section: NetworkSection.tor,
              ),
              HomeWarningDestination.swap => SwapNavigation.openSettings(
                context,
              ),
            },
            onOpenSilent: () => SilentNavigation.openWallet(context),
            ark: (refresh, scope) {
              if (arkHost == null) return const SizedBox.shrink();
              return NetworkCapabilityVisibility(
                capability: NetworkCapability.ark,
                child: ArkHomeCard(
                  key: ValueKey(scope),
                  host: arkHost,
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
            bottomActions: OverviewWalletButtons.home(
              receiveLabel: context.loc.walletButtonReceive,
              sendLabel: context.loc.walletButtonSend,
              onReceive: (target) => _openReceive(context, target),
              onSend: (key) => SendNavigation.open(context, wallet: key),
            ),
          );
        },
      ),
    ),
  );

  static GoRoute walletDetailRoute({
    required Widget Function(String walletId, Widget child) scopeWalletHistory,
    required Future<void> Function(BuildContext, WalletKey) onOpenCoins,
    required Future<Result<CoinSummary, CoinsFailure>> Function(String)
    loadCoinSummary,
  }) => GoRoute(
    name: WalletRoute.walletDetail.name,
    path: WalletRoute.walletDetail.path,
    builder: (context, state) {
      final walletId = state.pathParameters['walletId'];
      if (walletId == null) return const SizedBox.shrink();
      return _SelectedWalletHome(
        key: ValueKey(walletId),
        walletId: walletId,
        scopeWalletHistory: scopeWalletHistory,
        onOpenCoins: onOpenCoins,
        loadCoinSummary: loadCoinSummary,
      );
    },
  );
}

class _SelectedWalletHome extends StatefulWidget {
  final String walletId;
  final Widget Function(String, Widget) scopeWalletHistory;
  final Future<void> Function(BuildContext, WalletKey) onOpenCoins;
  final Future<Result<CoinSummary, CoinsFailure>> Function(String)
  loadCoinSummary;

  const _SelectedWalletHome({
    super.key,
    required this.walletId,
    required this.scopeWalletHistory,
    required this.onOpenCoins,
    required this.loadCoinSummary,
  });

  @override
  State<_SelectedWalletHome> createState() => _SelectedWalletHomeState();
}

class _SelectedWalletHomeState extends State<_SelectedWalletHome> {
  late final OverviewCatalogue _catalogue = locator<OverviewCatalogue>();
  late final OverviewDetailController _controller =
      OverviewDetailController.byId(
        catalogue: _catalogue,
        walletId: widget.walletId,
      );
  late final Stream<void> _syncCompletions = _refreshCompletions(
    locator<OverviewHomeController>(),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OverviewSelectedWalletDetail(
    controller: _controller,
    defaultBitcoinLabel: context.loc.globalDefaultBitcoinWalletLabel,
    defaultLiquidLabel: context.loc.globalDefaultLiquidWalletLabel,
    unavailableMessage: context.loc.walletLoadFailed,
    settings: IconButton(
      tooltip: context.loc.settingsWalletSettingsTitle,
      onPressed: () => SettingsNavigation.openWalletDetails(
        context,
        walletId: widget.walletId,
      ),
      icon: Image.asset(
        Assets.icons.settingsLine.path,
        width: 24,
        height: 24,
        color: context.appColors.onSurface,
      ),
    ),
    scopeWalletHistory: widget.scopeWalletHistory,
    refreshPrice: (context) => BitcoinPriceFeature.refresh(context),
    refreshWalletHistory: (context) => WalletHistoryScope.refresh(
      context,
      () => locator<OverviewHomeController>().refresh(),
    ),
    balanceCard: (context, wallet) => WalletDetailBalanceCard(
      background: AssetImage(
        wallet.key.network is LiquidNetwork
            ? Assets.backgrounds.bgInstantWallet.path
            : Assets.backgrounds.bgSecureWallet.path,
      ),
      isLiquid: wallet.key.network is LiquidNetwork,
      signer: switch (wallet.signer) {
        WalletSigner.local => SignerEntity.local,
        WalletSigner.remote => SignerEntity.remote,
        WalletSigner.none => SignerEntity.none,
      },
      balanceText: WalletDetailBalanceAmount(
        balanceSat: wallet.balanceSat?.toInt() ?? 0,
      ),
      eyeToggle: ValueListenableBuilder<OverviewHomeState>(
        valueListenable: locator<OverviewHomeController>(),
        builder: (context, state, _) => EyeToggle(
          hideAmounts: state.hideAmounts,
          showLabel: context.loc.walletShowAmountsTooltip,
          hideLabel: context.loc.walletHideAmountsTooltip,
          onChanged: (hide) => Settings.setAmountsHidden(context, hide),
        ),
      ),
      fiatBalance: HomeFiatBalance(
        onCurrencyChanged: Settings.changeDisplayCurrency,
        balanceSat: wallet.balanceSat?.toInt() ?? 0,
      ),
      syncingIndicator: const TxsSyncingIndicator(),
    ),
    consolidation: (context, wallet) =>
        ValueListenableBuilder<OverviewHomeState>(
          valueListenable: locator<OverviewHomeController>(),
          builder: (context, state, _) => ConsolidationBanner(
            consolidation: context.read<Consolidation>(),
            walletId: wallet.key.id,
            isRefreshing: state.isRefreshing,
          ),
        ),
    coinsEntry: (context, wallet) => wallet.key.network is LiquidNetwork
        ? const SizedBox.shrink()
        : CoinsEntry(
            walletId: wallet.key.id,
            label: context.loc.walletButtonCoins,
            loadCoinSummary: widget.loadCoinSummary,
            syncCompletions: _syncCompletions,
            onOpen: (context, id) => widget.onOpenCoins(context, wallet.key),
          ),
    liquidDisclosure: (context, wallet) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: BullDisclosureLink(
        label: context.loc.walletLiquidRiskDisclosureLabel,
        semanticLabel: context.loc.liquidRiskDisclosureSemanticLabel,
        title: context.loc.liquidRiskDisclosureTitle,
        body: context.loc.liquidRiskDisclosureBody,
        closeLabel: context.loc.closeDialogButton,
      ),
    ),
    history: (context, wallet) => const WalletDetailTxsList(sliver: true),
    receiveLabel: context.loc.walletButtonReceive,
    sendLabel: context.loc.walletButtonSend,
    onReceive: (target) => _openReceive(context, target),
    onSend: (key) => SendNavigation.open(context, wallet: key),
  );
}

class _EmptyNetworkHome extends StatefulWidget {
  final NetworkWalletProvisioning Function() provisioning;

  const _EmptyNetworkHome({required this.provisioning});

  @override
  State<_EmptyNetworkHome> createState() => _EmptyNetworkHomeState();
}

class _EmptyNetworkHomeState extends State<_EmptyNetworkHome> {
  late final Stream<bool> _refreshing = _refreshStates(
    locator<OverviewHomeController>(),
  );

  @override
  Widget build(BuildContext context) => OnboardingFeature.emptyNetworkWallets(
    provisioning: widget.provisioning,
    refreshing: _refreshing,
    initiallyRefreshing: locator<OverviewHomeController>().value.isRefreshing,
    onMainnet: () => OnboardingNavigation.go(GoRouter.of(context)),
    onImport: () => OnboardingNavigation.openPhysicalRecovery(context),
    onRecoverEncryptedVault: () =>
        RecoverBullFeature.open(context, RecoverBullFlow.recoverVault),
    onReady: () => locator<OverviewHomeController>().refreshVisible(),
  );
}

Stream<bool> _refreshStates(OverviewHomeController home) {
  late StreamController<bool> output;
  void publish() => output.add(home.value.isRefreshing);
  output = StreamController<bool>.broadcast(
    onListen: () {
      home.addListener(publish);
      publish();
    },
    onCancel: () => home.removeListener(publish),
  );
  return output.stream;
}

Stream<void> _refreshCompletions(OverviewHomeController home) {
  late StreamController<void> output;
  var wasRefreshing = home.value.isRefreshing;
  void publish() {
    final refreshing = home.value.isRefreshing;
    if (wasRefreshing && !refreshing) output.add(null);
    wasRefreshing = refreshing;
  }

  output = StreamController<void>.broadcast(
    onListen: () => home.addListener(publish),
    onCancel: () => home.removeListener(publish),
  );
  return output.stream;
}

void _openReceive(BuildContext context, OverviewReceiveTarget? target) =>
    ReceiveNavigation.open<void>(
      context,
      wallet: target == null
          ? null
          : ReceiveWallet(
              id: target.key.id,
              network: target.key.network,
              scriptType: target.scriptType,
              signsLocally: target.signsLocally,
            ),
    );

String _walletName(BuildContext context, OverviewHomeRow row) {
  if (row.selection.isDefault) {
    return row.selection.key.network is LiquidNetwork
        ? context.loc.globalDefaultLiquidWalletLabel
        : context.loc.globalDefaultBitcoinWalletLabel;
  }
  return row.selection.label ?? row.origin;
}

WalletPickerCopy _pickerCopy(BuildContext context) => (
  defaultBitcoinTitle: context.loc.globalDefaultBitcoinWalletLabel,
  defaultLiquidTitle: context.loc.globalDefaultLiquidWalletLabel,
  bitcoinDescription: context.loc.walletTypeBitcoinNetwork,
  liquidDescription: context.loc.walletTypeLiquidAndLightning,
  remoteDescription: context.loc.walletTypeWatchSigner,
  watchOnlyDescription: context.loc.walletTypeWatchOnly,
  unavailableLabel: context.loc.walletLoadFailed,
  silentTitle: context.loc.walletSpTitle,
  silentDescription: context.loc.walletSpExperimental,
);

HomeWarningsCopy _warningsCopy(BuildContext context) => (
  bitcoinDown: context.loc.walletWarningElectrumBitcoinDown,
  liquidDown: context.loc.walletWarningElectrumLiquidDown,
  bothDown: context.loc.walletWarningElectrumBothDown,
  electrumAction: context.loc.walletWarningElectrumAction,
  tor: (
    title: context.loc.torSettingsExternalProxyUnavailable,
    description: context.loc.torSettingsExternalProxyUnavailableDescription,
  ),
  swap: (
    title: context.loc.walletWarningSwapServerUnreachable,
    description: context.loc.walletWarningSwapServerAction,
  ),
  balancesMayBeStale: context.loc.walletBalancesMayBeStale,
  loadFailed: context.loc.walletLoadFailed,
  cannotDeleteDefaultWallet: context.loc.walletDeletionErrorDefaultWallet,
  cannotDeleteWithOngoingSwaps: context.loc.walletDeletionErrorOngoingSwaps,
  walletNotFound: context.loc.walletDeletionErrorWalletNotFound,
  unexpected: context.loc.oopsSomethingWentWrong,
  retryHint: context.loc.walletLoadFailedRetryHint,
);
