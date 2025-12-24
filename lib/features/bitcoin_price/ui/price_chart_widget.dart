import 'dart:math' as math;

import 'package:bb_mobile/core/exchange/domain/entity/rate.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/price_input/price_input.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

extension _CurrencyIconExtension on String {
  String get currencyIcon {
    switch (this) {
      case 'USD':
        return '🇺🇸';
      case 'EUR':
        return '🇪🇺';
      case 'CAD':
        return '🇨🇦';
      case 'CRC':
        return '🇨🇷';
      case 'MXN':
        return '🇲🇽';
      case 'ARS':
        return '🇦🇷';
      case 'COP':
        return '🇨🇴';
      case 'sats':
      case 'BTC':
      default:
        return '₿';
    }
  }
}

class PriceChartWidget extends StatelessWidget {
  const PriceChartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PriceChartCubit, PriceChartState>(
      builder: (context, state) {
        final rates = state.prices;
        final hasNoLocalData = rates.isEmpty;

        if (state.isLoading || hasNoLocalData) {
          if (state.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: context.appColors.onPrimary),
                  const Gap(16),
                  BBText(
                    context.loc.priceChartFetchingHistory,
                    style: context.font.bodyLarge?.copyWith(
                      color: context.appColors.onPrimary,
                    ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }
        final selectedIndex = state.selectedDataPointIndex;
        final currency =
            state.currency ??
            context.select((SettingsCubit cubit) => cubit.state.currencyCode) ??
            'CAD';

        return Padding(
          padding: const EdgeInsets.only(bottom: 40.0),
          child: Stack(
            children: [
              Column(
                children: [
                  const Gap(72),
                  if (selectedIndex != null && selectedIndex < rates.length)
                    _PriceDisplay(
                      rate: rates[selectedIndex],
                      currency: currency,
                    )
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
                          context.read<PriceChartCubit>().selectDataPoint(
                            index,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PriceDisplay extends StatelessWidget {
  const _PriceDisplay({required this.rate, required this.currency});

  final Rate rate;
  final String currency;

  Future<void> _openCurrencyBottomSheet(BuildContext context) async {
    List<String> availableCurrencies;

    try {
      final blocState = context.read<BitcoinPriceBloc>().state;
      if (blocState.availableCurrencies != null &&
          blocState.availableCurrencies!.isNotEmpty) {
        availableCurrencies = blocState.availableCurrencies!;
      } else {
        final usecase = locator<GetAvailableCurrenciesUsecase>();
        availableCurrencies = await usecase.execute();
      }
    } catch (e) {
      return;
    }

    if (availableCurrencies.isEmpty || !context.mounted) {
      return;
    }

    final selectedCurrency = await BlurredBottomSheet.show<String?>(
      context: context,
      child: CurrencyBottomSheet(
        availableCurrencies: availableCurrencies,
        selectedValue: currency,
      ),
    );

    if (selectedCurrency != null &&
        selectedCurrency != currency &&
        context.mounted) {
      context.read<PriceChartCubit>().changeCurrency(selectedCurrency);
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = rate.indexPrice ?? rate.price ?? 0.0;
    final dateFormat = DateFormat('MMM d, yyyy HH:mm');
    final date = rate.createdAt;

    return Builder(
      builder: (builderContext) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _openCurrencyBottomSheet(builderContext);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 16.0,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      currency.currencyIcon,
                      style: context.font.headlineSmall,
                    ),
                    const Gap(6),
                    BBText(
                      currency,
                      style: context.font.bodyMedium?.copyWith(
                        color: context.appColors.onPrimary.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _openCurrencyBottomSheet(builderContext);
              },
              child: Center(
                child: BBText(
                  NumberFormat.currency(
                    symbol: '',
                    decimalDigits: 2,
                  ).format(price),
                  style: context.font.displaySmall?.copyWith(
                    color: context.appColors.onPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const Gap(4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _openCurrencyBottomSheet(builderContext);
              },
              child: Center(
                child: BBText(
                  dateFormat.format(date.toLocal()),
                  style: context.font.bodySmall?.copyWith(
                    color: context.appColors.onPrimary.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
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
  bool _isDragging = false;

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

    final currentIndex =
        widget.selectedIndex ?? _touchedIndex ?? (widget.rates.length - 1);
    if (currentIndex != _previousIndex && !_isDragging) {
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

    return GestureDetector(
      onHorizontalDragStart: (_) {
        setState(() {
          _isDragging = true;
        });
      },
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;

        final localPosition = box.globalToLocal(details.globalPosition);
        final width = box.size.width;
        final index = ((localPosition.dx / width) * rates.length)
            .clamp(0, rates.length - 1)
            .toInt();

        if (index != _touchedIndex) {
          setState(() {
            _touchedIndex = index;
          });
          widget.onTap(index);
        }
      },
      onHorizontalDragEnd: (_) {
        setState(() {
          _isDragging = false;
        });
      },
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;

        final localPosition = box.globalToLocal(details.globalPosition);
        final width = box.size.width;
        final index = ((localPosition.dx / width) * rates.length)
            .clamp(0, rates.length - 1)
            .toInt();

        setState(() {
          _touchedIndex = index;
        });
        widget.onTap(index);
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _lineAnimation,
          _pulseAnimation,
          _dotPositionAnimation,
        ]),
        builder: (context, child) {
          return CustomPaint(
            size: Size.infinite,
            painter: _ChartPainter(
              prices: prices,
              minPrice: minPrice - padding,
              maxPrice: maxPrice + padding,
              lineColor: context.appColors.onPrimary,
              selectedIndex: displayIndex,
              lineAnimation: _lineAnimation.value,
              pulseScale: _pulseAnimation.value,
              dotColor: context.appColors.onTertiary,
              borderColor: context.appColors.onPrimary,
            ),
          );
        },
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.prices,
    required this.minPrice,
    required this.maxPrice,
    required this.lineColor,
    this.selectedIndex,
    required this.lineAnimation,
    required this.pulseScale,
    required this.dotColor,
    required this.borderColor,
  });

  final List<double> prices;
  final double minPrice;
  final double maxPrice;
  final Color lineColor;
  final int? selectedIndex;
  final double lineAnimation;
  final double pulseScale;
  final Color dotColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.isEmpty) return;

    final priceRange = maxPrice - minPrice;
    final stepX = size.width / (prices.length - 1);

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.1
      ..style = PaintingStyle.stroke;

    final shadowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final visibleCount = (prices.length * lineAnimation).ceil();
    final startIndex = (prices.length - visibleCount).clamp(
      0,
      prices.length - 1,
    );

    final points = <Offset>[];
    for (var i = 0; i < prices.length; i++) {
      double y;
      if (i >= startIndex) {
        final normalizedPrice = (prices[i] - minPrice) / priceRange;
        y = size.height - (normalizedPrice * size.height);
      } else if (startIndex > 0) {
        final normalizedPrice = (prices[startIndex] - minPrice) / priceRange;
        y = size.height - (normalizedPrice * size.height);
      } else {
        final normalizedPrice = (prices.last - minPrice) / priceRange;
        y = size.height - (normalizedPrice * size.height);
      }

      final x = i * stepX;
      if (i >= startIndex) {
        points.add(Offset(x, y));
      }
    }

    if (points.isEmpty) return;

    path.moveTo(points.first.dx, points.first.dy);

    if (points.length == 1) {
      path.lineTo(points.first.dx, points.first.dy);
    } else if (points.length == 2) {
      path.lineTo(points.last.dx, points.last.dy);
    } else {
      for (var i = 0; i < points.length - 1; i++) {
        final p0 = i > 0 ? points[i - 1] : points[i];
        final p1 = points[i];
        final p2 = points[i + 1];
        final p3 = i < points.length - 2 ? points[i + 2] : p2;

        final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
        final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
        final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
        final cp2y = p2.dy - (p3.dy - p1.dy) / 6;

        path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
      }
    }

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);

    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < prices.length) {
      final x = selectedIndex! * stepX;
      final normalizedPrice = (prices[selectedIndex!] - minPrice) / priceRange;
      final y = size.height - (normalizedPrice * size.height);

      final dotRadius = 6.0 * pulseScale;
      final glowRadius = dotRadius + 4;

      final glowPaint = Paint()
        ..color = dotColor.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawCircle(Offset(x, y), glowRadius, glowPaint);

      final dotPaint = Paint()
        ..color = dotColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);

      final borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(Offset(x, y), dotRadius, borderPaint);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) {
    return oldDelegate.prices != prices ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.lineAnimation != lineAnimation ||
        oldDelegate.pulseScale != pulseScale;
  }
}
