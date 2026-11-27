import 'package:bull_ui/app_theme.dart';
import 'package:bitcoin_price/bitcoin_price.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullAmount,
        BullHeaderBackground,
        BullQuickActionBar,
        BullShimmerBox,
        BullTypographyX,
        Gap;

class WalletHomeTopSection extends StatelessWidget {
  const WalletHomeTopSection({
    super.key,
    required this.actions,
    required this.background,
    required this.totalSat,
    required this.isLoading,
    required this.hideAmounts,
    required this.unavailableLabel,
    required this.onCurrencyChanged,
    required this.showChart,
    required this.chart,
    required this.onCloseChart,
    required this.closeChartLabel,
  });

  final Widget actions;
  final ImageProvider background;
  final int? totalSat;
  final bool isLoading;
  final bool? hideAmounts;
  final String unavailableLabel;
  final void Function(BuildContext, String) onCurrencyChanged;
  final bool showChart;
  final Widget chart;
  final VoidCallback onCloseChart;
  final String closeChartLabel;

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
          child: BullHeaderBackground(background),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _balanceAreaHeight),
              child: _content(context),
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

  Widget _content(BuildContext context) {
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
          ? SizedBox(
              key: const ValueKey('chart'),
              height: _chartHeight,
              child: Stack(
                children: [
                  Positioned.fill(child: chart),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + kToolbarHeight,
                    left: 8,
                    child: IconButton(
                      tooltip: closeChartLabel,
                      icon: Icon(
                        Icons.arrow_back,
                        color: context.appColors.onPrimary,
                      ),
                      onPressed: onCloseChart,
                    ),
                  ),
                ],
              ),
            )
          : _amounts(context),
    );
  }

  Widget _amounts(BuildContext context) {
    final total = totalSat;
    return Column(
      key: const ValueKey('amounts'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Gap(_balanceTopSpacing),
        if (isLoading || hideAmounts == null)
          const BullShimmerBox(
            width: 200,
            height: 40,
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
          )
        else if (total == null)
          Text(unavailableLabel)
        else
          BullAmount.signedSats(
            total,
            forceHideAmounts: hideAmounts == true,
            style: context.bullType.headline,
            color: context.appColors.onPrimary,
          ),
        const Gap(6),
        if (total == null)
          Text(unavailableLabel)
        else
          HomeFiatBalance(
            balanceSat: total,
            showBalanceLoading: isLoading,
            forceHideAmounts: hideAmounts ?? true,
            onCurrencyChanged: onCurrencyChanged,
          ),
      ],
    );
  }
}
