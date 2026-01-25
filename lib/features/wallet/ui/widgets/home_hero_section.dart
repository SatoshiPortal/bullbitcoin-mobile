import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/price_chart_widget.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/auto_swap_fee_warning.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/eye_toggle.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_errors.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_fiat_balance.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_quick_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class HomeHeroSection extends StatelessWidget {
  const HomeHeroSection({super.key});

  static const double fixedHeight = 280.0;

  @override
  Widget build(BuildContext context) {
    final showChart = context.select(
      (PriceChartCubit cubit) => cubit.state.showChart,
    );

    return SizedBox(
      height: fixedHeight,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: showChart
            ? const _ChartView(key: ValueKey('chart'))
            : const _BalanceAndActions(key: ValueKey('balance')),
      ),
    );
  }
}

class _BalanceAndActions extends StatelessWidget {
  const _BalanceAndActions({super.key});

  @override
  Widget build(BuildContext context) {
    final isSyncing = context.select((WalletBloc bloc) => bloc.state.isSyncing);
    final hideAmounts = context.select(
      (SettingsCubit cubit) => cubit.state.hideAmounts ?? false,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: BBText(
            isSyncing ? 'Syncing...' : 'Last synced: just now',
            style: context.font.labelSmall,
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(8),
        if (hideAmounts)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const EyeToggle(),
            ],
          )
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const _BtcTotalAmt(),
              const Gap(8),
              const EyeToggle(),
              const Spacer(),
            ],
          ),
          const Gap(12),
          const _FiatAmt(),
          const _UnconfirmedIncomingBalance(),
        ],
        const Gap(8),
        const HomeQuickActions(),
        const HomeWarnings(),
        const AutoSwapFeeWarning(),
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
