import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar_bull_logo.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_cards.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_funding_buttons.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_top_section.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullPullableBody, BullSupportButton, Gap;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ExchangeHomeScreen extends StatelessWidget {
  final List<Widget> homeCards;
  final VoidCallback onHomeRefresh;
  final VoidCallback onOpenSettings;

  const ExchangeHomeScreen({
    required this.homeCards,
    required this.onHomeRefresh,
    required this.onOpenSettings,
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

    if (isFetchingUserSummary || notLoggedIn) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        BullPullableBody(
          onRefresh: () async {
            onHomeRefresh();
            await context.read<ExchangeCubit>().fetchUserSummary();
          },
          slivers: [
            const PinnedHeaderSliver(child: ExchangeHomeTopSection()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: ExchangeHomeCards(homeCards: homeCards),
              ),
            ),
          ],
          bottomChild: Padding(
            padding: const EdgeInsets.all(16),
            child: ExchangeHomeFundingButtons(),
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
                              BullSupportButton.icon(
                                label: context.loc.exchangeSupportChatTitle,
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
                          onTap: onOpenSettings,
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
