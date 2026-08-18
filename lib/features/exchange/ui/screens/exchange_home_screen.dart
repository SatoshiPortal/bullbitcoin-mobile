import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar_bull_logo.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/announcement_banner.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/dca_list_tile.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_kyc_card.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_top_section.dart';
import 'package:bb_mobile/features/exchange_support_chat/public/exchange_support_chat_facade.dart';
import 'package:bb_mobile/features/fund_exchange/fund_exchange_router.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/withdraw/ui/withdraw_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ExchangeHomeScreen extends StatelessWidget {
  const ExchangeHomeScreen({super.key});

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
    final dca = context.select((ExchangeCubit cubit) => cubit.state.dca);
    final hasDcaActive = dca?.isActive ?? false;

    if (isFetchingUserSummary || notLoggedIn) {
      return const Center(child: CircularProgressIndicator());
    }

    // The transparent app bar floats over the scrollable content (the
    // colored top section extends behind it). A static overlay is almost
    // identical to the previous pinned SliverAppBar inside a SliverStack:
    // the bar never scrolls away, and the theme pins scrolledUnderElevation
    // to 0 so no tint appears on scroll. One accepted difference: a drag
    // starting on the bar's buttons no longer scrolls the list, since the
    // bar is now a Stack sibling above the scroll view instead of a sliver
    // inside it.
    return Stack(
      children: [
        BullPullableBody(
          onRefresh: () async {
            await context.read<ExchangeCubit>().fetchUserSummary();
          },
          slivers: [
            SliverList(
              delegate: SliverChildListDelegate([
                const ExchangeHomeTopSection(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      const Gap(12),
                      if (!isFullyVerified) const ExchangeHomeKycCard(),
                      const Gap(12),
                      DcaListTile(hasDcaActive: hasDcaActive, dca: dca),
                      const Gap(12),
                      if (!notLoggedIn) const AnnouncementBanner(),
                    ],
                  ),
                ),
              ]),
            ),
          ],
          bottomChild: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: BullButton.big(
                    iconData: Icons.arrow_downward,
                    label: context.loc.exchangeHomeDepositButton,
                    iconFirst: true,
                    onPressed: () =>
                        context.pushNamed(FundExchangeRoute.fundExchange.name),
                    bgColor: context.appColors.secondaryFixed,
                    textColor: context.appColors.onSecondaryFixed,
                    outlined: true,
                    borderColor: context.appColors.onSecondaryFixed,
                  ),
                ),
                const Gap(4),
                Expanded(
                  child: BullButton.big(
                    iconData: Icons.arrow_upward,
                    label: context.loc.exchangeHomeWithdrawButton,
                    iconFirst: true,
                    disabled: false,
                    onPressed: () =>
                        context.pushNamed(WithdrawRoute.withdraw.name),
                    bgColor: context.appColors.secondaryFixed,
                    textColor: context.appColors.onSecondaryFixed,
                    outlined: true,
                    borderColor: context.appColors.onSecondaryFixed,
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
          child: BlocBuilder<PriceChartCubit, PriceChartState>(
            builder: (context, priceChartState) {
              final showChart = priceChartState.showChart;

              return AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                title: showChart ? null : const TopBarBullLogo(),
                leading: Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: showChart
                      ? IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color: context.appColors.onPrimary,
                            size: 24,
                          ),
                          onPressed: () {
                            context.read<PriceChartCubit>().hideChart();
                          },
                        )
                      : SizedBox(
                          width: 96,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  Icons.show_chart,
                                  color: context.appColors.onPrimary,
                                  size: 24,
                                ),
                                onPressed: () {
                                  context.read<PriceChartCubit>().showChart();
                                },
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  Icons.chat_bubble_outline,
                                  color: context.appColors.onPrimary,
                                  size: 24,
                                ),
                                onPressed: () {
                                  final notLoggedIn = context
                                      .read<ExchangeCubit>()
                                      .state
                                      .notLoggedIn;
                                  if (notLoggedIn) {
                                    context.pushNamed(
                                      ExchangeRoute
                                          .exchangeLoginForSupport
                                          .name,
                                    );
                                  } else {
                                    context.pushNamed(
                                      ExchangeSupportChatFacade.routeName,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                ),
                leadingWidth: showChart ? 56 : 112,
                actionsIconTheme: IconThemeData(
                  color: context.appColors.onPrimary,
                  size: 24,
                ),
                actionsPadding: const EdgeInsets.only(right: 16),
                actions: showChart
                    ? null
                    : [
                        IconButton(
                          onPressed: () {
                            context.pushNamed(
                              TransactionsRoute.transactions.name,
                            );
                          },
                          visualDensity: VisualDensity.compact,
                          color: context.appColors.onPrimary,
                          iconSize: 32,
                          icon: const Icon(Icons.history),
                        ),
                        const Gap(16),
                        InkWell(
                          onTap: () =>
                              context.pushNamed(SettingsRoute.settings.name),
                          child: Image.asset(
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
