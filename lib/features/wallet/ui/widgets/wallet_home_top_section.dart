import 'package:settings/settings.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bitcoin_price/bitcoin_price.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullAmount,
        BullHeaderBackground,
        BullQuickActionBar,
        BullShapesX,
        BullTypographyX,
        Gap;
import 'package:shimmer/shimmer.dart';

class WalletHomeTopSection extends StatelessWidget {
  const WalletHomeTopSection({super.key, required this.actions});

  final Widget actions;

  /// Minimum height of the dark area behind the balance.
  static const double _balanceAreaHeight = 208;

  /// Height of the price chart when it replaces the balance.
  static const double _chartHeight = 224;

  /// Distance from the top of the dark area down to the balance.
  static const double _balanceTopSpacing = 112;

  /// Backdrop kept visible between the balance and the quick actions card.
  static const double _actionsTopSpacing = 25;

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
          child: BullHeaderBackground(
            AssetImage(Assets.backgrounds.bgRed.path),
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
              height: WalletHomeTopSection._chartHeight,
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
        _BtcTotalAmt(),
        Gap(6),
        _FiatAmt(),
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

    return BullAmount.signedSats(
      btcTotal,
      interactive: true,
      style: context.bullType.headline,
      color: context.appColors.onPrimary,
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
      onCurrencyChanged: Settings.changeDisplayCurrency,
      balanceSat: total,
      showBalanceLoading: showBalanceLoading,
    );
  }
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
