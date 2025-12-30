import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar_bull_logo.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/announcement_banner.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/dca_list_tile.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_kyc_card.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_top_section.dart';
import 'package:bb_mobile/features/exchange_support_chat/ui/exchange_support_chat_router.dart';
import 'package:bb_mobile/features/fund_exchange/ui/fund_exchange_router.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/withdraw/ui/withdraw_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:sliver_tools/sliver_tools.dart';

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

    return RefreshIndicator(
      edgeOffset: 30,
      onRefresh: () async {
        await context.read<ExchangeCubit>().fetchUserSummary();
      },
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverStack(
                children: [
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
                            /*
                            SwitchListTile(
                              value: false,
                              onChanged: (value) {},
                              title: const Text('Activate auto-buy'),
                            ),

                        const Gap(12),
                        ListTile(
                          title: const Text('View auto-sell address'),
                          onTap: () {},
                          trailing: const Icon(Icons.arrow_forward),
                        ),
                        const Gap(12),
                        */
                            // Add bottom padding to account for fixed button bar
                            const Gap(100),
                          ],
                        ),
                      ), // Bottom-aligned button
                    ]),
                  ),
                  BlocBuilder<PriceChartCubit, PriceChartState>(
                    builder: (context, priceChartState) {
                      final showChart = priceChartState.showChart;
                      final hasApiKey = context.select(
                        (ExchangeCubit cubit) => cubit.state.apiKeyException == null,
                      );

                      return SliverAppBar(
                        backgroundColor: Colors.transparent,
                        floating: true,
                        pinned: true,
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
                                  width: hasApiKey ? 96 : 48,
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
                                          context
                                              .read<PriceChartCubit>()
                                              .showChart();
                                        },
                                      ),
                                      if (hasApiKey)
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
                                            context.pushNamed(
                                              ExchangeSupportChatRoute
                                                  .supportChat.name,
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                        ),
                        leadingWidth: showChart ? 56 : (hasApiKey ? 112 : 56),
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
                                  onTap: () => context.pushNamed(
                                    SettingsRoute.settings.name,
                                  ),
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
                ],
              ),
            ],
          ),
          Positioned(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: BBButton.big(
                        iconData: Icons.arrow_downward,
                        label: context.loc.exchangeHomeDepositButton,
                        iconFirst: true,
                        onPressed: () => context.pushNamed(
                          FundExchangeRoute.fundExchangeAccount.name,
                        ),
                        bgColor: context.appColors.secondaryFixed,
                        textColor: context.appColors.onSecondaryFixed,
                        outlined: true,
                        borderColor: context.appColors.onSecondaryFixed,
                      ),
                    ),
                    const Gap(4),
                    Expanded(
                      child: BBButton.big(
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
          ),
        ],
      ),
    );
  }
}
