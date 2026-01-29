import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/action_card.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/price_chart_widget.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class ExchangeHomeTopSection extends StatelessWidget {
  const ExchangeHomeTopSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    final balances = context.select(
      (ExchangeCubit cubit) => cubit.state.userSummary?.displayBalances ?? [],
    );
    final balanceTextStyle = switch (balances.length) {
      0 => theme.textTheme.displayMedium,
      1 => theme.textTheme.displayMedium,
      2 => theme.textTheme.displaySmall,
      _ => theme.textTheme.headlineLarge,
    };

    final topGap = balances.length > 3 ? 32.0 : 46.0;

    final showChart = context.select(
      (PriceChartCubit cubit) => cubit.state.showChart,
    );

    return SizedBox(
      height: 264 + 78 + 46,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: context.appColors.secondaryFixed,
                height: 264 + 78,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return SlideTransition(
                          position:
                              Tween<Offset>(
                                begin: const Offset(1.0, 0.0),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeInOut,
                                ),
                              ),
                          child: child,
                        );
                      },
                      child: showChart
                          ? const _ChartView(key: ValueKey('chart'))
                          : _BalancesView(
                              key: const ValueKey('balances'),
                              balances: balances,
                              balanceTextStyle: balanceTextStyle,
                              topGap: topGap,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 13.0),
              child: ActionCard(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalancesView extends StatelessWidget {
  const _BalancesView({
    super.key,
    required this.balances,
    required this.balanceTextStyle,
    required this.topGap,
  });

  final List<dynamic> balances;
  final TextStyle? balanceTextStyle;
  final double topGap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Gap(topGap),
        if (balances.isEmpty)
          BBText(
            '0.00',
            style: balanceTextStyle?.copyWith(
              color: context.appColors.onSecondaryFixed,
              fontWeight: FontWeight.w500,
            ),
          )
        else
          ...balances.map(
            (b) => BBText(
              '${b.amount} ${b.currencyCode}',
              style: balanceTextStyle?.copyWith(
                color: context.appColors.onSecondaryFixed,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

class _ChartView extends StatelessWidget {
  const _ChartView({super.key});

  @override
  Widget build(BuildContext context) {
    return const PriceChartWidget();
  }
}
