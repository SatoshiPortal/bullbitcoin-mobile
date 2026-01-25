import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/price_chart_widget.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/eye_toggle.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_fiat_balance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class HomeBalanceSection extends StatelessWidget {
  const HomeBalanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final showChart = context.select(
      (PriceChartCubit cubit) => cubit.state.showChart,
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          ),
          child: child,
        );
      },
      child: showChart
          ? const _ChartView(key: ValueKey('chart'))
          : const _Amounts(key: ValueKey('amounts')),
    );
  }
}

class _Amounts extends StatelessWidget {
  const _Amounts({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [const Spacer(), const _BtcTotalAmt(), const Gap(8), const EyeToggle(), const Spacer()],
        ),
        const _FiatAmt(),
        const _UnconfirmedIncomingBalance(),
      ],
    );
  }
}

class _BtcTotalAmt extends StatelessWidget {
  const _BtcTotalAmt();

  @override
  Widget build(BuildContext context) {
    final btcTotal = context.select(
      (WalletBloc bloc) => bloc.state.totalBalance(),
    );

    return CurrencyText(
      btcTotal,
      showFiat: false,
      style: context.font.displaySmall,
      color: context.appColors.text,
    );
  }
}

class _FiatAmt extends StatelessWidget {
  const _FiatAmt();

  @override
  Widget build(BuildContext context) {
    final totalBal = context.select(
      (WalletBloc bloc) => bloc.state.totalBalance(),
    );

    return HomeFiatBalance(balanceSat: totalBal);
  }
}

class _ChartView extends StatelessWidget {
  const _ChartView({super.key});

  @override
  Widget build(BuildContext context) {
    return const PriceChartWidget();
  }
}

class _UnconfirmedIncomingBalance extends StatelessWidget {
  const _UnconfirmedIncomingBalance();

  @override
  Widget build(BuildContext context) {
    final unconfirmed = context.select(
      (WalletBloc bloc) => bloc.state.unconfirmedIncomingBalance,
    );
    if (unconfirmed == 0) return const SizedBox.shrink();
    final color = context.appColors.primary;
    return GestureDetector(
      onTap: () {
        context.pushNamed(TransactionsRoute.transactions.name);
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_downward, color: color, size: 20),
                CurrencyText(
                  unconfirmed,
                  showFiat: false,
                  style: context.font.bodyLarge,
                  color: color,
                ),
              ],
            ),
            Align(
              child: Text(
                context.loc.walletBalanceUnconfirmedIncoming,
                style: context.font.bodyLarge?.copyWith(
                  color: context.appColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
