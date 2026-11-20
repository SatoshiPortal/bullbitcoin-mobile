import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_actions.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/price_chart_widget.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullText, BullQuickActionBar, Gap, BullTypographyX;

class ExchangeHomeTopSection extends StatelessWidget {
  const ExchangeHomeTopSection({required this.onAction, super.key});

  final void Function(ExchangeHomeAction) onAction;

  /// Height of the dark balance area.
  static const double _balanceAreaHeight = 264 + 78;

  /// How far the actions card hangs below the dark area: half of it straddles
  /// the bottom edge.
  static double _actionsOverhang(BuildContext context) =>
      BullQuickActionBar.heightOf(context) / 2;

  @override
  Widget build(BuildContext context) {
    final balances = context.select(
      (ExchangeCubit cubit) => cubit.state.displayBalances,
    );
    final balanceTextStyle = switch (balances.length) {
      0 => context.bullType.display,
      1 => context.bullType.display,
      2 => context.bullType.headline,
      _ => context.bullType.subtitle.copyWith(fontWeight: FontWeight.w700),
    };

    final topGap = balances.length > 3 ? 32.0 : 46.0;

    final showChart = context.select(
      (PriceChartCubit cubit) => cubit.state.showChart,
    );

    return SizedBox(
      height: _balanceAreaHeight + _actionsOverhang(context),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: context.appColors.secondaryFixed,
                height: _balanceAreaHeight,
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
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13.0),
              child: ExchangeHomeActions(onAction: onAction),
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
          BullText(
            '0.00',
            style: balanceTextStyle?.copyWith(
              color: context.appColors.onSecondaryFixed,
              fontWeight: FontWeight.w500,
            ),
          )
        else
          ...balances.map(
            (b) => BullText(
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
