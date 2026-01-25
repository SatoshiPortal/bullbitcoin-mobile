import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/price_chart_widget.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/eye_toggle.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_quick_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class ExchangeHomeTopSection extends StatelessWidget {
  const ExchangeHomeTopSection({super.key});

  static const double _heroHeight = 200.0;

  @override
  Widget build(BuildContext context) {
    final showChart = context.select(
      (PriceChartCubit cubit) => cubit.state.showChart,
    );

    return SizedBox(
      height: _heroHeight,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: showChart
            ? const _ChartView(key: ValueKey('chart'))
            : const _BalancesAndActionsView(key: ValueKey('balances')),
      ),
    );
  }
}

class _BalancesAndActionsView extends StatelessWidget {
  const _BalancesAndActionsView({super.key});

  @override
  Widget build(BuildContext context) {
    final balances = context.select(
      (ExchangeCubit cubit) => cubit.state.userSummary?.displayBalances ?? [],
    );
    final hideAmounts = context.select(
      (SettingsCubit cubit) => cubit.state.hideAmounts ?? false,
    );
    final balanceTextStyle = switch (balances.length) {
      1 => context.font.headlineLarge,
      2 => context.font.headlineMedium,
      _ => context.font.titleLarge,
    };

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hideAmounts)
          const EyeToggle()
        else
          ...balances.map(
            (b) => BBText(
              '${b.amount} ${b.currencyCode}',
              style: balanceTextStyle?.copyWith(
                color: context.appColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const Gap(8),
        const HomeQuickActions(),
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
