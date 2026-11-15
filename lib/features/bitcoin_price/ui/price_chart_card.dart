import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bitcoin_price_failure_l10n.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/price_chart_widget.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_ui/bull_ui.dart' show BullShapesX, BullSpacing, Gap;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

enum _Range {
  week(Duration(days: 7)),
  month(Duration(days: 30)),
  all(null);

  const _Range(this.duration);

  final Duration? duration;
}

/// The bitcoin price with its change and chart, on a plain surface.
class PriceChartCard extends StatefulWidget {
  const PriceChartCard({super.key});

  @override
  State<PriceChartCard> createState() => _PriceChartCardState();
}

class _PriceChartCardState extends State<PriceChartCard> {
  _Range _range = _Range.month;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    context.read<PriceChartCubit>().loadPriceHistory();
  }

  List<PricePoint> _inRange(List<PricePoint> prices) {
    final duration = _range.duration;
    if (duration == null || prices.isEmpty) return prices;
    final from = prices.last.time.subtract(duration);
    final inRange = prices.where((p) => !p.time.isBefore(from)).toList();
    return inRange.length >= 2 ? inRange : prices;
  }

  String _rangeLabel(BuildContext context, _Range range) => switch (range) {
    _Range.week => context.loc.priceChartRangeWeek,
    _Range.month => context.loc.priceChartRangeMonth,
    _Range.all => context.loc.priceChartRangeAll,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final state = context.watch<PriceChartCubit>().state;
    final prices = _inRange(state.prices);
    final failure = state.failure;

    final Widget body;
    if (prices.length < 2) {
      body = Center(
        child: failure != null
            ? Column(
                mainAxisSize: .min,
                children: [
                  Text(
                    failure.toTranslated(context),
                    textAlign: .center,
                    style: context.font.bodyMedium?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                  IconButton(
                    onPressed: () => context
                        .read<PriceChartCubit>()
                        .loadPriceHistory(currency: state.currency),
                    icon: Icon(Icons.refresh, color: colors.text),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      );
    } else {
      final hovered = _hoveredIndex;
      final shown = hovered != null && hovered < prices.length
          ? prices[hovered]
          : prices.last;
      final first = prices.first.fiatAmount;
      final change = first == 0 ? 0.0 : (shown.fiatAmount - first) / first;
      final changeColor = change < 0 ? colors.error : colors.success;
      final currency = state.currency ?? shown.currency.code;

      body = Column(
        crossAxisAlignment: .stretch,
        children: [
          Row(
            crossAxisAlignment: .end,
            children: [
              Flexible(
                child: Text(
                  NumberFormat.currency(
                    symbol: '',
                    decimalDigits: 2,
                  ).format(shown.fiatAmount),
                  maxLines: 1,
                  overflow: .ellipsis,
                  style: context.font.headlineLarge?.copyWith(
                    color: colors.text,
                    fontSize: 28,
                    fontWeight: .w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const Gap(BullSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  currency,
                  style: context.font.bodyMedium?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ),
              const Gap(BullSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${change >= 0 ? '+' : ''}'
                  '${NumberFormat.decimalPercentPattern(decimalDigits: 2).format(change)}',
                  style: context.font.bodyMedium?.copyWith(
                    color: changeColor,
                    fontWeight: .w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          Text(
            DateFormat.yMMMd().add_Hm().format(shown.time.toLocal()),
            style: context.font.labelMedium?.copyWith(color: colors.textMuted),
          ),
          const Gap(BullSpacing.md),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => MouseRegion(
                onHover: (event) {
                  final index =
                      ((event.localPosition.dx / constraints.maxWidth) *
                              prices.length)
                          .clamp(0, prices.length - 1)
                          .toInt();
                  if (index != _hoveredIndex) {
                    setState(() => _hoveredIndex = index);
                  }
                },
                onExit: (_) => setState(() => _hoveredIndex = null),
                child: PriceLineChart(
                  key: ValueKey(_range),
                  rates: prices,
                  selectedIndex: hovered ?? prices.length - 1,
                  onTap: (_) {},
                  lineColor: colors.text,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(context.bullShapes.card),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BullSpacing.lg),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.loc.priceChartCardTitle,
                    style: context.font.bodyMedium?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ),
                for (final range in _Range.values)
                  _RangeChip(
                    label: _rangeLabel(context, range),
                    selected: range == _range,
                    onTap: () => setState(() {
                      _range = range;
                      _hoveredIndex = null;
                    }),
                  ),
              ],
            ),
            const Gap(BullSpacing.xs),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final radius = BorderRadius.circular(context.bullShapes.chip);
    return Padding(
      padding: const EdgeInsets.only(left: BullSpacing.xxs),
      child: Material(
        color: selected ? colors.surfaceContainerHighest : colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BullSpacing.sm,
              vertical: BullSpacing.xxs,
            ),
            child: Text(
              label,
              style: context.font.labelMedium?.copyWith(
                color: selected ? colors.text : colors.textMuted,
                fontWeight: selected ? .w600 : .w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
