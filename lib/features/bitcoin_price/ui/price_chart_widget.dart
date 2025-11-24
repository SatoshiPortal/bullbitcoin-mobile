import 'dart:math' as math;

import 'package:bb_mobile/core/exchange/domain/entity/rate_history.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/price_chart_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

class PriceChartWidget extends StatelessWidget {
  const PriceChartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PriceChartBloc, PriceChartState>(
      builder: (context, state) {
        if (state.isLoading && state.rateHistory == null) {
          return Center(
            child: CircularProgressIndicator(color: context.colour.onPrimary),
          );
        }

        final rateHistory = state.rateHistory;
        if (rateHistory == null ||
            rateHistory.rates == null ||
            rateHistory.rates!.isEmpty) {
          return Center(
            child: BBText(
              'No data available',
              style: context.font.bodyLarge?.copyWith(
                color: context.colour.onPrimary,
              ),
            ),
          );
        }

        final rates = rateHistory.rates!;
        final selectedIndex = state.selectedDataPointIndex;
        final currency = state.currency ?? 'CAD';

        return Stack(
          children: [
            Column(
              children: [
                const Gap(
                  72,
                ), // Space for app bar - currency aligned with back button
                if (selectedIndex != null && selectedIndex < rates.length)
                  _PriceDisplay(rate: rates[selectedIndex], currency: currency)
                else if (rates.isNotEmpty)
                  _PriceDisplay(rate: rates.last, currency: currency),
                const Gap(16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: _Chart(
                      rates: rates,
                      selectedIndex: selectedIndex,
                      onTap: (index) {
                        context.read<PriceChartBloc>().add(
                          PriceChartEvent.dataPointSelected(index),
                        );
                      },
                    ),
                  ),
                ),
                const Gap(16),
                _IntervalButtons(
                  selectedInterval:
                      state.selectedInterval ?? RateTimelineInterval.week,
                  onIntervalChanged: (interval) {
                    context.read<PriceChartBloc>().add(
                      PriceChartEvent.intervalChanged(interval),
                    );
                  },
                ),
                const Gap(16),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _PriceDisplay extends StatelessWidget {
  const _PriceDisplay({required this.rate, required this.currency});

  final Rate rate;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final price = rate.indexPrice ?? rate.price ?? 0.0;
    final dateFormat = DateFormat('MMM d, yyyy HH:mm');
    final date = rate.createdAt;

    return Column(
      children: [
        BBText(
          currency,
          style: context.font.bodyMedium?.copyWith(
            color: context.colour.onPrimary.withValues(alpha: 0.7),
          ),
        ),
        const Gap(4),
        BBText(
          NumberFormat.currency(symbol: '', decimalDigits: 2).format(price),
          style: context.font.displaySmall?.copyWith(
            color: context.colour.onPrimary,
          ),
        ),
        if (date != null) ...[
          const Gap(4),
          BBText(
            dateFormat.format(date.toLocal()),
            style: context.font.bodySmall?.copyWith(
              color: context.colour.onPrimary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }
}

class _Chart extends StatefulWidget {
  const _Chart({
    required this.rates,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<Rate> rates;
  final int? selectedIndex;
  final ValueChanged<int> onTap;

  @override
  State<_Chart> createState() => _ChartState();
}

class _ChartState extends State<_Chart> with TickerProviderStateMixin {
  int? _touchedIndex;
  late AnimationController _lineAnimationController;
  late Animation<double> _lineAnimation;
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  late AnimationController _dotPositionController;
  late Animation<double> _dotPositionAnimation;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _lineAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _lineAnimation = CurvedAnimation(
      parent: _lineAnimationController,
      curve: Curves.easeInOutCubic,
    );
    _lineAnimationController.forward();

    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _pulseAnimationController.repeat(reverse: true);

    _dotPositionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _dotPositionAnimation = CurvedAnimation(
      parent: _dotPositionController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(_Chart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rates != widget.rates) {
      _lineAnimationController.reset();
      _lineAnimationController.forward();
    }

    final currentIndex =
        widget.selectedIndex ?? _touchedIndex ?? (widget.rates.length - 1);
    if (currentIndex != _previousIndex) {
      _previousIndex = currentIndex;
      _dotPositionController.reset();
      _dotPositionController.forward();
    }
  }

  @override
  void dispose() {
    _lineAnimationController.dispose();
    _pulseAnimationController.dispose();
    _dotPositionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rates = widget.rates;
    if (rates.isEmpty) return const SizedBox.shrink();

    final prices = rates.map((r) => r.indexPrice ?? r.price ?? 0.0).toList();
    final minPrice = prices.reduce(math.min);
    final maxPrice = prices.reduce(math.max);
    final priceRange = maxPrice - minPrice;
    final padding = priceRange * 0.1;

    final displayIndex =
        widget.selectedIndex ?? _touchedIndex ?? rates.length - 1;

    final lineColor = context.colour.onPrimary.withValues(alpha: 0.75);

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;

        final localPosition = box.globalToLocal(details.globalPosition);
        final width = box.size.width;
        final index =
            ((localPosition.dx / width) * rates.length)
                .clamp(0, rates.length - 1)
                .toInt();

        if (index != _touchedIndex) {
          setState(() {
            _touchedIndex = index;
          });
          widget.onTap(index);
        }
      },
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;

        final localPosition = box.globalToLocal(details.globalPosition);
        final width = box.size.width;
        final index =
            ((localPosition.dx / width) * rates.length)
                .clamp(0, rates.length - 1)
                .toInt();

        setState(() {
          _touchedIndex = index;
        });
        widget.onTap(index);
      },
      child: AnimatedBuilder(
        animation: _lineAnimation,
        builder: (context, child) {
          final progress = _lineAnimation.value;
          // Draw from right to left (starting at the dot position)
          // Calculate how many points from the end should be visible
          final visibleCount = (rates.length * progress).ceil();
          final startIndex = (rates.length - visibleCount).clamp(
            0,
            rates.length - 1,
          );

          final animatedSpots = List.generate(rates.length, (index) {
            // Show points from the end backwards
            if (index >= startIndex) {
              return FlSpot(index.toDouble(), prices[index]);
            } else if (startIndex > 0) {
              // For points before the visible range, use the first visible point's position
              // This creates the effect of the line "growing" from the dot
              return FlSpot(index.toDouble(), prices[startIndex]);
            } else {
              // At the very start, all points use the last price
              return FlSpot(index.toDouble(), prices.last);
            }
          });

          return Stack(
            children: [
              LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: animatedSpots,
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: lineColor,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                      shadow: Shadow(
                        color: lineColor.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ),
                  ],
                  minY: minPrice - padding,
                  maxY: maxPrice + padding,
                  lineTouchData: const LineTouchData(enabled: false),
                  clipData: const FlClipData.all(),
                ),
              ),
              if (displayIndex < rates.length)
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _pulseAnimation,
                    _dotPositionAnimation,
                  ]),
                  builder: (context, child) {
                    return Positioned.fill(
                      child: CustomPaint(
                        painter: _RedDotPainter(
                          index: displayIndex,
                          totalPoints: rates.length,
                          price: prices[displayIndex],
                          minPrice: minPrice - padding,
                          maxPrice: maxPrice + padding,
                          dotColor: context.colour.onTertiary,
                          borderColor: context.colour.onPrimary,
                          pulseScale: _pulseAnimation.value,
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _IntervalButtons extends StatelessWidget {
  const _IntervalButtons({
    required this.selectedInterval,
    required this.onIntervalChanged,
  });

  final RateTimelineInterval selectedInterval;
  final ValueChanged<RateTimelineInterval> onIntervalChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _IntervalButton(
          label: 'Day',
          interval: RateTimelineInterval.hour,
          isSelected: selectedInterval == RateTimelineInterval.hour,
          onTap: () => onIntervalChanged(RateTimelineInterval.hour),
        ),
        const Gap(8),
        _IntervalButton(
          label: 'Month',
          interval: RateTimelineInterval.day,
          isSelected: selectedInterval == RateTimelineInterval.day,
          onTap: () => onIntervalChanged(RateTimelineInterval.day),
        ),
        const Gap(8),
        _IntervalButton(
          label: 'Year',
          interval: RateTimelineInterval.week,
          isSelected: selectedInterval == RateTimelineInterval.week,
          onTap: () => onIntervalChanged(RateTimelineInterval.week),
        ),
      ],
    );
  }
}

class _RedDotPainter extends CustomPainter {
  _RedDotPainter({
    required this.index,
    required this.totalPoints,
    required this.price,
    required this.minPrice,
    required this.maxPrice,
    required this.dotColor,
    required this.borderColor,
    this.pulseScale = 1.0,
  });

  final int index;
  final int totalPoints;
  final double price;
  final double minPrice;
  final double maxPrice;
  final Color dotColor;
  final Color borderColor;
  final double pulseScale;

  @override
  void paint(Canvas canvas, Size size) {
    final x =
        totalPoints > 1
            ? (index / (totalPoints - 1)) * size.width
            : size.width / 2;
    final priceRange = maxPrice - minPrice;
    final normalizedPrice =
        priceRange > 0 ? (price - minPrice) / priceRange : 0.5;
    final y = size.height - (normalizedPrice * size.height);

    final dotRadius = 6.0 * pulseScale;
    final glowRadius = dotRadius + 4;

    final glowPaint =
        Paint()
          ..color = dotColor.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawCircle(Offset(x, y), glowRadius, glowPaint);

    final paint =
        Paint()
          ..color = dotColor
          ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(x, y), dotRadius, paint);

    final borderPaint =
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    canvas.drawCircle(Offset(x, y), dotRadius, borderPaint);
  }

  @override
  bool shouldRepaint(_RedDotPainter oldDelegate) {
    return oldDelegate.index != index ||
        oldDelegate.price != price ||
        oldDelegate.totalPoints != totalPoints ||
        oldDelegate.pulseScale != pulseScale;
  }
}

class _IntervalButton extends StatelessWidget {
  const _IntervalButton({
    required this.label,
    required this.interval,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final RateTimelineInterval interval;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? context.colour.onPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: context.colour.onPrimary, width: 1),
        ),
        child: BBText(
          label,
          style: context.font.bodyMedium?.copyWith(
            color:
                isSelected
                    ? context.colour.secondary
                    : context.colour.onPrimary,
          ),
        ),
      ),
    );
  }
}
