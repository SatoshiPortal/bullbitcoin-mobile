import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/autobuy/public/autobuy_facade.dart';
import 'package:bitcoin_price/bitcoin_price.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_failure_l10n.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/announcement_banner.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/dca_list_tile.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_kyc_card.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_top_section.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_actions.dart';
import 'package:bb_mobile/features/fund_exchange/public/fund_exchange_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:transactions/routes.dart';
import 'package:bb_mobile/features/withdraw/public/withdraw_facade.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_failure_banner.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullErrorState, BullPullableBody, BullSupportButton, Gap;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ExchangeHomeScreen extends StatelessWidget {
  final List<Widget> homeCards;
  final VoidCallback onHomeRefresh;
  final VoidCallback onOpenSettings;
  final void Function(ExchangeHomeAction) onAction;
  final VoidCallback onExit;

  const ExchangeHomeScreen({
    required this.homeCards,
    required this.onHomeRefresh,
    required this.onOpenSettings,
    required this.onAction,
    required this.onExit,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isFetchingUserSummary = context.select(
      (ExchangeCubit cubit) => cubit.state.isFetchingUserSummary,
    );
    final notLoggedIn = context.select(
      (ExchangeCubit cubit) => cubit.state.notLoggedIn,
    );
    final isFullyVerified = context.select(
      (ExchangeCubit cubit) => cubit.state.isFullyVerifiedKycLevel,
    );
    final getUserSummaryFailure = context.select(
      (ExchangeCubit cubit) => cubit.state.getUserSummaryFailure,
    );
    final stopDcaFailure = context.select(
      (ExchangeCubit cubit) => cubit.state.stopDcaFailure,
    );
    final dca = context.select((ExchangeCubit cubit) => cubit.state.dca);
    final hasDcaActive = dca?.isActive ?? false;
    final autoBuy = context.select(
      (ExchangeCubit cubit) => cubit.state.userSummary?.autoBuy,
    );
    final isFundingRestricted = context.select(
      (ExchangeCubit cubit) =>
          cubit.state.userSummary?.isFundingRestricted ?? true,
    );

    if (notLoggedIn && getUserSummaryFailure != null) {
      return _WithExit(
        onExit: onExit,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: BullErrorState(
              message: getUserSummaryFailure.toTranslated(context),
              retryLabel: context.loc.retry,
              onRetry: () => context.read<ExchangeCubit>().fetchUserSummary(),
            ),
          ),
        ),
      );
    }

    if (isFetchingUserSummary || notLoggedIn) {
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
            await context.read<ExchangeCubit>().fetchUserSummary();
          },
          slivers: [
            PinnedHeaderSliver(
              child: ExchangeHomeTopSection(onAction: onAction),
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
                      ExchangeFailureBanner(
                        failure: getUserSummaryFailure,
                        onRetry: () =>
                            context.read<ExchangeCubit>().fetchUserSummary(),
                      ),
                      const Gap(12),
                    ],
                    if (stopDcaFailure != null) ...[
                      ExchangeFailureBanner(
                        failure: stopDcaFailure,
                        onRetry: () => context.read<ExchangeCubit>().stopDca(),
                      ),
                      const Gap(12),
                    ],
                    if (!isFullyVerified) ...[
                      const ExchangeHomeKycCard(),
                      const Gap(12),
                    ],
                    DcaListTile(hasDcaActive: hasDcaActive, dca: dca),
                    const Gap(12),
                    locator<AutoBuyFacade>().buildHomeCard(
                      isActive: autoBuy?.isActive ?? false,
                      isRestricted: isFundingRestricted,
                      onActivate: () async {
                        await context.pushNamed(AutoBuyRoute.autoBuy.name);
                        if (context.mounted) {
                          await context
                              .read<ExchangeCubit>()
                              .fetchUserSummary();
                        }
                      },
                      onStatusChanged: () =>
                          context.read<ExchangeCubit>().fetchUserSummary(),
                    ),
                    const Gap(12),
                    for (final card in homeCards) ...[card, const Gap(12)],
                    if (!notLoggedIn) const AnnouncementBanner(),
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
                    onPressed: () =>
                        context.pushNamed(WithdrawRoute.withdraw.name),
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
                    : Assets.logos.bbLogoSmall.image(width: 40, height: 40),
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
                          onPressed: () {
                            TransactionsNavigation.openHistory(context);
                          },
                          color: context.appColors.onPrimary,
                          iconSize: 32,
                          icon: const Icon(Icons.history),
                        ),
                        const Gap(8),
                        IconButton(
                          tooltip: context.loc.settingsScreenTitle,
                          onPressed: onOpenSettings,
                          icon: Image.asset(
                            Assets.icons.settingsLine.path,
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
