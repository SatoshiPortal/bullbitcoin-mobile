import 'package:bb_mobile/core/exchange/domain/entity/order_stats.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/statistics_cubit.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/statistics_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ExchangeStatisticsScreen extends StatefulWidget {
  const ExchangeStatisticsScreen({super.key});

  @override
  State<ExchangeStatisticsScreen> createState() =>
      _ExchangeStatisticsScreenState();
}

class _ExchangeStatisticsScreenState extends State<ExchangeStatisticsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<StatisticsCubit>().loadStatistics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.exchangeStatisticsTitle,
          onBack: () => context.pop(),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final state = context.watch<StatisticsCubit>().state;

    return Column(
      children: [
        if (state.isLoading)
          LinearProgressIndicator(
            backgroundColor: context.appColors.surface,
            color: context.appColors.primary,
          ),
        Expanded(
          child: _buildContent(context, state),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, StatisticsState state) {
    if (state.isLoading && !state.hasStats) {
      return const SizedBox.shrink();
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BBText(
              state.error!,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.error,
              ),
            ),
            const SizedBox(height: 16),
            BBButton.big(
              label: context.loc.retry,
              onPressed: () => context.read<StatisticsCubit>().loadStatistics(),
              bgColor: context.appColors.onSurface,
              textColor: context.appColors.surface,
            ),
          ],
        ),
      );
    }

    if (!state.hasStats) {
      return Center(
        child: BBText(
          context.loc.exchangeStatisticsNoData,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.outline,
          ),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.asOf != null) ...[
                BBText(
                  context.loc.exchangeStatisticsAsOf(
                    DateFormat('MMM d, yyyy HH:mm').format(state.asOf!),
                  ),
                  style: context.font.bodySmall?.copyWith(
                    color: context.appColors.outline,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _OrderStatsSection(
                orderStats: state.orderStats!,
                userCurrency: state.userCurrency,
              ),
              const SizedBox(height: 24),
              if (state.billerStats != null && state.billerStats!.hasStats)
                _BillerStatsSection(billerStats: state.billerStats!),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderStatsSection extends StatelessWidget {
  const _OrderStatsSection({
    required this.orderStats,
    required this.userCurrency,
  });

  final OrderStats orderStats;
  final String userCurrency;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          context.loc.exchangeStatisticsOrderStats,
          style: context.font.headlineMedium?.copyWith(
            color: context.appColors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _StatCard(
          title: context.loc.exchangeStatisticsBuySellRatio,
          description: context.loc.exchangeStatisticsBuySellRatioDesc,
          value: orderStats.buySellRatio,
          icon: Icons.compare_arrows,
          context: context,
        ),
        const SizedBox(height: 12),
        _StatSectionCard(
          title: context.loc.exchangeStatisticsBuyStats,
          icon: Icons.arrow_downward,
          iconColor: Colors.green,
          stats: [
            _buildStatRow(
              context,
              context.loc.exchangeStatisticsVolume,
              _formatVolumeAmount(orderStats.bitcoinBuyVolume),
              description: context.loc.exchangeStatisticsBuyVolumeDesc,
            ),
            _buildStatRow(
              context,
              context.loc.exchangeStatisticsTradeCount,
              _formatTradeCount(orderStats.bitcoinBuyTradeCount),
              description: context.loc.exchangeStatisticsBuyTradeCountDesc,
            ),
            _buildStatRow(
              context,
              context.loc.exchangeStatisticsAveragePrice,
              _formatFiatAmount(orderStats.averageBitcoinBuyPrice),
              description: context.loc.exchangeStatisticsBuyAvgPriceDesc,
            ),
          ],
          context: context,
        ),
        const SizedBox(height: 12),
        _StatSectionCard(
          title: context.loc.exchangeStatisticsSellStats,
          icon: Icons.arrow_upward,
          iconColor: Colors.red,
          stats: [
            _buildStatRow(
              context,
              context.loc.exchangeStatisticsVolume,
              _formatVolumeAmount(orderStats.bitcoinSellVolume),
              description: context.loc.exchangeStatisticsSellVolumeDesc,
            ),
            _buildStatRow(
              context,
              context.loc.exchangeStatisticsTradeCount,
              _formatTradeCount(orderStats.bitcoinSellTradeCount),
              description: context.loc.exchangeStatisticsSellTradeCountDesc,
            ),
            _buildStatRow(
              context,
              context.loc.exchangeStatisticsAveragePrice,
              _formatFiatAmount(orderStats.averageBitcoinSellPrice),
              description: context.loc.exchangeStatisticsSellAvgPriceDesc,
            ),
          ],
          context: context,
        ),
        const SizedBox(height: 12),
        _StatCard(
          title: context.loc.exchangeStatisticsTotalVolume,
          description: context.loc.exchangeStatisticsTotalVolumeDesc,
          value: _formatVolumeAmount(orderStats.totalBitcoinTradingVolume),
          icon: Icons.trending_up,
          context: context,
        ),
      ],
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    String label,
    String value, {
    String? description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText(
                  label,
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  BBText(
                    description,
                    style: context.font.bodySmall?.copyWith(
                      color: context.appColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          BBText(
            value,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Format volume amounts - prefer fiat in user currency, fallback to BTC
  /// Shows currency code for clarity (e.g., "$279.57 CAD")
  String _formatVolumeAmount(List<AmountByCurrencyCode> amounts) {
    if (amounts.isEmpty) return '0';

    // First, look for user's selected currency (already converted from CAD)
    final userAmount =
        amounts.where((a) => a.currency == userCurrency).firstOrNull;
    if (userAmount != null) {
      return _formatWithCurrencyCode(userAmount.value, userCurrency);
    }

    // Look for any fiat amount (non-BTC)
    final fiatAmount = amounts.where((a) => a.currency != 'BTC').firstOrNull;
    if (fiatAmount != null) {
      return _formatWithCurrencyCode(fiatAmount.value, fiatAmount.currency);
    }

    // Fallback to BTC if no fiat available
    final btcAmount = amounts.where((a) => a.currency == 'BTC').firstOrNull;
    if (btcAmount != null) {
      return '${_formatNumber(btcAmount.value)} BTC';
    }

    // Final fallback
    final first = amounts.first;
    return '${_formatNumber(first.value)} ${first.currency}';
  }

  /// Format trade count (plain integer, no currency)
  String _formatTradeCount(List<AmountByCurrencyCode> counts) {
    if (counts.isEmpty) return '0';

    // Sum all trade counts across currencies
    final total = counts.fold(0.0, (sum, c) => sum + c.value);
    return total.toInt().toString();
  }

  /// Format fiat amounts (for average price) using user's selected currency
  /// Shows currency code for clarity (e.g., "$167.84K CAD")
  String _formatFiatAmount(List<AmountByCurrencyCode> amounts) {
    if (amounts.isEmpty) return '0';

    // Find amount in user's selected currency
    final userAmount =
        amounts.where((a) => a.currency == userCurrency).firstOrNull;
    if (userAmount != null) {
      return _formatWithCurrencyCode(userAmount.value, userCurrency);
    }

    // Fallback to first available amount
    final first = amounts.first;
    return _formatWithCurrencyCode(first.value, first.currency);
  }

  /// Format a value with currency code only (e.g., "279.57 CAD")
  String _formatWithCurrencyCode(double value, String currencyCode) {
    return '${_formatNumber(value)} $currencyCode';
  }

  /// Format number with thousands separator, no abbreviations
  String _formatNumber(double value) {
    if (value < 1 && value > 0) {
      return value.toStringAsFixed(8);
    }
    // Format with 2 decimal places and thousands separator
    return _formatWithThousandsSeparator(value);
  }

  /// Format number with thousands separator (e.g., 1234567.89 -> "1,234,567.89")
  String _formatWithThousandsSeparator(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '00';

    // Add thousands separators
    final buffer = StringBuffer();
    final digits = intPart.replaceFirst('-', '');
    final isNegative = intPart.startsWith('-');

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }

    final formatted = '${isNegative ? '-' : ''}${buffer.toString()}.$decPart';
    return formatted;
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.context,
    this.description,
  });

  final String title;
  final String value;
  final IconData icon;
  final BuildContext context;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: context.appColors.overlay.withValues(alpha: 0.05),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.appColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: context.appColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText(
                  title,
                  style: context.font.bodySmall?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                BBText(
                  value,
                  style: context.font.headlineSmall?.copyWith(
                    color: context.appColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 6),
                  BBText(
                    description!,
                    style: context.font.bodySmall?.copyWith(
                      color: context.appColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatSectionCard extends StatelessWidget {
  const _StatSectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.stats,
    required this.context,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> stats;
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: context.appColors.overlay.withValues(alpha: 0.05),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              BBText(
                title,
                style: context.font.labelLarge?.copyWith(
                  color: context.appColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...stats,
        ],
      ),
    );
  }
}

class _BillerStatsSection extends StatelessWidget {
  const _BillerStatsSection({required this.billerStats});

  final BillerStats billerStats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          context.loc.exchangeStatisticsBillerStats,
          style: context.font.headlineMedium?.copyWith(
            color: context.appColors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (billerStats.currency.isNotEmpty)
          BBText(
            context.loc.exchangeStatisticsCurrency(billerStats.currency),
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
        const SizedBox(height: 16),
        ...billerStats.stats.map(
          (stat) => _BillerStatCard(
            stat: stat,
            currencyCode: billerStats.currency,
          ),
        ),
      ],
    );
  }
}

class _BillerStatCard extends StatelessWidget {
  const _BillerStatCard({
    required this.stat,
    required this.currencyCode,
  });

  final BillerStat stat;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: context.appColors.overlay.withValues(alpha: 0.05),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBText(
            stat.displayName,
            style: context.font.labelLarge?.copyWith(
              color: context.appColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  context.loc.exchangeStatisticsTotalAmount,
                  _formatAmount(stat.totalAmount),
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  context.loc.exchangeStatisticsTradeCount,
                  stat.tradeCount.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          label,
          style: context.font.bodySmall?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        BBText(
          value,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatAmount(double value) {
    final code = currencyCode.isNotEmpty ? currencyCode : 'CAD';
    return '${_formatWithThousandsSeparator(value)} $code';
  }

  /// Format number with thousands separator (e.g., 1234567.89 -> "1,234,567.89")
  String _formatWithThousandsSeparator(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '00';

    // Add thousands separators
    final buffer = StringBuffer();
    final digits = intPart.replaceFirst('-', '');
    final isNegative = intPart.startsWith('-');

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }

    final formatted = '${isNegative ? '-' : ''}${buffer.toString()}.$decPart';
    return formatted;
  }
}

