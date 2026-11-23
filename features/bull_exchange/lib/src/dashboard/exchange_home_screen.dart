import '../exchange_l10n.dart';
import '../autobuy/autobuy_mount.dart';
import '../funding/fund_exchange_router.dart';
import 'announcement_banner.dart';
import 'dca_list_tile.dart';
import 'exchange_home_actions.dart';
import 'exchange_home_kyc_card.dart';
import 'exchange_home_top_section.dart';

import 'dart:async';

import 'package:bitcoin_price/bitcoin_price.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullErrorState,
        BullInfoCard,
        BullPullableBody,
        BullSupportButton,
        Gap;
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

typedef ExchangeDashboardState = ({
  UserSummary? summary,
  List<UserBalance> displayBalances,
  ExchangeFailure? summaryFailure,
  ExchangeFailure? stopDcaFailure,
  List<Announcement> announcements,
});

class ExchangeHomeScreen extends StatelessWidget {
  final ExchangeDashboardState Function(BuildContext) watchDashboard;
  final Exchange Function() exchange;
  final Preferences Function() preferences;
  final String brandAsset;
  final String settingsAsset;
  final Future<void> Function() refreshAccount;
  final Future<void> Function() stopDca;
  final VoidCallback onOpenDca;
  final VoidCallback onWithdraw;
  final VoidCallback onHistory;
  final String Function(BuildContext, ExchangeFailure) failureMessage;
  final List<Widget> homeCards;
  final VoidCallback onHomeRefresh;
  final VoidCallback onOpenSettings;
  final void Function(ExchangeHomeAction) onAction;
  final VoidCallback onExit;

  const ExchangeHomeScreen({
    required this.watchDashboard,
    required this.exchange,
    required this.preferences,
    required this.brandAsset,
    required this.settingsAsset,
    required this.refreshAccount,
    required this.stopDca,
    required this.onOpenDca,
    required this.onWithdraw,
    required this.onHistory,
    required this.failureMessage,
    required this.homeCards,
    required this.onHomeRefresh,
    required this.onOpenSettings,
    required this.onAction,
    required this.onExit,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final state = watchDashboard(context);
    final summary = state.summary;
    final notLoggedIn = summary == null;
    final getUserSummaryFailure = state.summaryFailure;
    final stopDcaFailure = state.stopDcaFailure;
    final isFullyVerified = summary?.isFullyVerifiedKycLevel ?? false;
    final dca = summary?.dca;
    final autoBuy = summary?.autoBuy;
    final isFundingRestricted = summary?.isFundingRestricted ?? true;

    if (notLoggedIn && getUserSummaryFailure != null) {
      return _WithExit(
        onExit: onExit,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: BullErrorState(
              message: failureMessage(context, getUserSummaryFailure),
              retryLabel: context.loc.retry,
              onRetry: refreshAccount,
            ),
          ),
        ),
      );
    }

    if (notLoggedIn) {
      return _WithExit(
        onExit: onExit,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Stack(
      children: [
        BullPullableBody(
          onRefresh: () async {
            onHomeRefresh();
            await refreshAccount();
          },
          slivers: [
            PinnedHeaderSliver(
              child: ExchangeHomeTopSection(
                onAction: onAction,
                balances: state.displayBalances,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    const Gap(12),
                    // A refresh that fails leaves stale data on screen; say
                    // so instead of letting it look current.
                    if (getUserSummaryFailure != null) ...[
                      BullInfoCard(
                        description: failureMessage(
                          context,
                          getUserSummaryFailure,
                        ),
                        tagColor: context.appColors.error,
                        bgColor: context.appColors.errorContainer,
                        onTap: refreshAccount,
                      ),
                      const Gap(12),
                    ],
                    if (stopDcaFailure != null) ...[
                      BullInfoCard(
                        description: failureMessage(context, stopDcaFailure),
                        tagColor: context.appColors.error,
                        bgColor: context.appColors.errorContainer,
                        onTap: stopDca,
                      ),
                      const Gap(12),
                    ],
                    if (!isFullyVerified) ...[
                      ExchangeHomeKycCard(
                        isKycLight: summary.isLightKycLevel,
                        isKycLimited: summary.isLimitedKycLevel,
                      ),
                      const Gap(12),
                    ],
                    DcaListTile(
                      hasDcaActive: dca?.isActive ?? false,
                      dca: dca,
                      onActivate: onOpenDca,
                      onDeactivate: stopDca,
                    ),
                    const Gap(12),
                    ExchangeAutoBuyCard(
                      exchange: exchange,
                      preferences: preferences,
                      isActive: autoBuy?.isActive ?? false,
                      isRestricted: isFundingRestricted,
                      onStatusChanged: refreshAccount,
                    ),
                    const Gap(12),
                    for (final card in homeCards) ...[card, const Gap(12)],
                    AnnouncementBanner(announcements: state.announcements),
                  ],
                ),
              ),
            ),
          ],
          bottomChild: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: BullButton.secondary(
                    iconData: Icons.arrow_downward,
                    label: context.loc.exchangeHomeDepositButton,
                    iconFirst: true,
                    onPressed: () =>
                        context.pushNamed(FundExchangeRoute.fundExchange.name),
                  ),
                ),
                const Gap(4),
                Expanded(
                  child: BullButton.secondary(
                    iconData: Icons.arrow_upward,
                    label: context.loc.exchangeHomeWithdrawButton,
                    iconFirst: true,
                    onPressed: onWithdraw,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Builder(
            builder: (context) {
              final showChart = BitcoinPriceFeature.watchChartVisible(context);

              return AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                title: showChart
                    ? null
                    : Image.asset(brandAsset, width: 40, height: 40),
                leading: Padding(
                  // 48 dp targets keep the back arrow where it was at 16.
                  padding: EdgeInsets.only(left: showChart ? 16.0 : 4.0),
                  child: showChart
                      ? IconButton(
                          tooltip: MaterialLocalizations.of(context)
                              .backButtonTooltip,
                          icon: Icon(
                            Icons.arrow_back,
                            color: context.appColors.onPrimary,
                            size: 24,
                          ),
                          onPressed: () {
                            BitcoinPriceFeature.hideChart(context);
                          },
                        )
                      : SizedBox(
                          width: 136,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              BackButton(
                                color: context.appColors.onPrimary,
                                onPressed: onExit,
                                style: IconButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                ),
                              ),
                              IconButton(
                                tooltip: context.loc.priceChartShowTooltip,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(
                                  Icons.show_chart,
                                  color: context.appColors.onPrimary,
                                  size: 24,
                                ),
                                onPressed: () {
                                  unawaited(
                                    BitcoinPriceFeature.showChart(context),
                                  );
                                },
                              ),
                              BullSupportButton.icon(
                                label: context.loc.exchangeSupportChatTitle,
                              ),
                            ],
                          ),
                        ),
                ),
                leadingWidth: showChart ? 56 : 152,
                actionsIconTheme: IconThemeData(
                  color: context.appColors.onPrimary,
                  size: 24,
                ),
                // 8 + the 48 dp settings target keep its icon 16 from the edge.
                actionsPadding: const EdgeInsets.only(right: 8),
                actions: showChart
                    ? null
                    : [
                        IconButton(
                          tooltip: context.loc.transactionHistoryTitle,
                          onPressed: onHistory,
                          color: context.appColors.onPrimary,
                          iconSize: 32,
                          icon: const Icon(Icons.history),
                        ),
                        const Gap(8),
                        IconButton(
                          tooltip: context.loc.settingsScreenTitle,
                          onPressed: onOpenSettings,
                          icon: Image.asset(
                            settingsAsset,
                            width: 32,
                            height: 32,
                            color: context.appColors.onPrimary,
                          ),
                        ),
                      ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Trade has no tab bar, and iOS has no system back: states without the
/// account toolbar still offer the way back to the wallet.
class _WithExit extends StatelessWidget {
  const _WithExit({required this.onExit, required this.child});

  final VoidCallback onExit;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      child,
      Positioned(
        top: 0,
        left: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: BackButton(onPressed: onExit),
          ),
        ),
      ),
    ],
  );
}
