import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bitcoin_price/bitcoin_price.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullAmount, BullQuickActionBar, BullShapesX, Gap, BullTypographyX;
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

class WalletHomeTopSection extends StatelessWidget {
  const WalletHomeTopSection({super.key, required this.actions});

  final Widget actions;

  /// Minimum height of the dark area behind the balance (and the price chart, when it
  /// is toggled on).
  static const double _balanceAreaHeight = 224;

  /// Distance from the top of the dark area down to the balance.
  static const double _balanceTopSpacing = 96;

  /// Backdrop kept visible between the balance and the quick actions card.
  static const double _actionsTopSpacing = 32;

  /// How far the quick actions card hangs below the background: half of it
  /// straddles the bottom edge, while the balance above is never covered.
  static double _actionsOverhang(BuildContext context) =>
      BullQuickActionBar.heightOf(context) / 2;

  /// Minimum height of the background image; anything painted behind this
  /// section must stay within it.
  static double minBackgroundHeight(BuildContext context) =>
      _balanceAreaHeight + _actionsTopSpacing + _actionsOverhang(context);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: _actionsOverhang(context),
          child: Image.asset(
            Assets.backgrounds.bgRed.path,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _balanceAreaHeight),
              child: const _UI(),
            ),
            const SizedBox(height: _actionsTopSpacing),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13.0),
              child: actions,
            ),
          ],
        ),
      ],
    );
  }
}

class _UI extends StatelessWidget {
  const _UI();

  @override
  Widget build(BuildContext context) {
    final showChart = BitcoinPriceFeature.watchChartVisible(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeInOut),
              ),
          child: child,
        );
      },
      child: showChart
          ? const SizedBox(
              key: ValueKey('chart'),
              height: WalletHomeTopSection._balanceAreaHeight,
              child: _ChartView(),
            )
          : const _Amounts(key: ValueKey('amounts')),
    );
  }
}

class _Amounts extends StatelessWidget {
  const _Amounts({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Gap(WalletHomeTopSection._balanceTopSpacing),
        Center(
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [_BtcTotalAmt(), Gap(12), _FiatAmt()],
            ),
          ),
        ),
        Gap(8),
        _UnconfirmedIncomingBalance(),
      ],
    );
  }
}

class _BtcTotalAmt extends StatelessWidget {
  const _BtcTotalAmt();

  @override
  Widget build(BuildContext context) {
    final walletState = context.select((WalletBloc bloc) => bloc.state);
    final bitcoinUnit = walletState.amountDisplay?.bitcoinUnit;

    final showSkeleton =
        walletState.status == WalletStatus.initial ||
        walletState.status == WalletStatus.loading ||
        bitcoinUnit == null;

    if (showSkeleton) {
      return const _WalletHomeBtcAmountSkeleton();
    }

    final btcTotal = walletState.totalBalance();
    if (btcTotal == null) return Text(context.loc.walletLoadFailed);

    return _HomeBalanceFrame(
      tint: context.appColors.bitcoinOrange,
      child: BullAmount.signedSats(
        btcTotal,
        interactive: true,
        style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
        color: context.appColors.onPrimary,
      ),
    );
  }
}

class _FiatAmt extends StatelessWidget {
  const _FiatAmt();

  @override
  Widget build(BuildContext context) {
    final walletState = context.select((WalletBloc bloc) => bloc.state);
    final showBalanceLoading =
        walletState.status == WalletStatus.initial ||
        walletState.status == WalletStatus.loading;

    final total = walletState.totalBalance();
    if (total == null) return Text(context.loc.walletLoadFailed);
    return HomeFiatBalance(
      onCurrencyChanged: SettingsFacade.changeDisplayCurrency,
      balanceSat: total,
      showBalanceLoading: showBalanceLoading,
      frameBuilder: (context, child) => _HomeBalanceFrame(
        tint: context.appColors.border,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: child,
        ),
      ),
    );
  }
}

/// Matches the unit toggle's minimum height for both balance controls.
class _HomeBalanceFrame extends StatelessWidget {
  const _HomeBalanceFrame({required this.tint, required this.child});

  final Color tint;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(context.bullShapes.button),
      border: Border.all(color: tint.withValues(alpha: 0.3)),
      color: tint.withValues(alpha: 0.3),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Align(
        alignment: Alignment.centerRight,
        widthFactor: 1,
        heightFactor: 1,
        child: child,
      ),
    ),
  );
}

class _WalletHomeBtcAmountSkeleton extends StatelessWidget {
  const _WalletHomeBtcAmountSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: context.appColors.shimmerBase,
      highlightColor: context.appColors.shimmerHighlight,
      child: SizedBox(
        width: 200,
        height: 40,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.appColors.surface,
            borderRadius: BorderRadius.circular(context.bullShapes.card),
          ),
        ),
      ),
    );
  }
}

class _ChartView extends StatelessWidget {
  const _ChartView();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: PriceChartWidget()),
        Positioned(
          top: MediaQuery.paddingOf(context).top + kToolbarHeight,
          left: 8,
          child: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: Icon(Icons.arrow_back, color: context.appColors.onPrimary),
            onPressed: () => BitcoinPriceFeature.hideChart(context),
          ),
        ),
      ],
    );
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
    final color = context.appColors.onPrimary;
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
                BullAmount.signedSats(
                  unconfirmed,
                  interactive: true,
                  style: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  color: color,
                ),
              ],
            ),
            Align(
              child: Text(
                context.loc.walletBalanceUnconfirmedIncoming,
                style: context.bullType.body
                    .copyWith(fontWeight: FontWeight.w500)
                    .copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
