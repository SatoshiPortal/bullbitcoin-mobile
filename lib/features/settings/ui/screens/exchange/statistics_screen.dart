import 'package:bb_mobile/core/exchange/domain/entity/order_stats.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/statistics_cubit.dart';
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

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
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
              _OrderStatsSection(orderStats: state.orderStats!),
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
  const _OrderStatsSection({required this.orderStats});

  final OrderStats orderStats;

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
            _buildAmountStatRow(
              context,
              context.loc.exchangeStatisticsVolume,
              orderStats.bitcoinBuyVolume,
            ),
            _buildAmountStatRow(
              context,
              context.loc.exchangeStatisticsTradeCount,
              orderStats.bitcoinBuyTradeCount,
            ),
            _buildAmountStatRow(
              context,
              context.loc.exchangeStatisticsAveragePrice,
              orderStats.averageBitcoinBuyPrice,
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
            _buildAmountStatRow(
              context,
              context.loc.exchangeStatisticsVolume,
              orderStats.bitcoinSellVolume,
            ),
            _buildAmountStatRow(
              context,
              context.loc.exchangeStatisticsTradeCount,
              orderStats.bitcoinSellTradeCount,
            ),
            _buildAmountStatRow(
              context,
              context.loc.exchangeStatisticsAveragePrice,
              orderStats.averageBitcoinSellPrice,
            ),
          ],
          context: context,
        ),
        const SizedBox(height: 12),
        _StatCard(
          title: context.loc.exchangeStatisticsTotalVolume,
          value: _formatAmountList(orderStats.totalBitcoinTradingVolume),
          icon: Icons.trending_up,
          context: context,
        ),
      ],
    );
  }

  Widget _buildAmountStatRow(
    BuildContext context,
    String label,
    List<AmountByCurrencyCode> amounts,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          BBText(
            label,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
          BBText(
            _formatAmountList(amounts),
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmountList(List<AmountByCurrencyCode> amounts) {
    if (amounts.isEmpty) return '0';

    // Show the first currency value or BTC if available
    final btcAmount = amounts.where((a) => a.currency == 'BTC').firstOrNull;
    if (btcAmount != null) {
      return '${_formatNumber(btcAmount.value)} BTC';
    }

    final first = amounts.first;
    return '${_formatNumber(first.value)} ${first.currency}';
  }

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(2)}K';
    } else if (value < 1) {
      return value.toStringAsFixed(8);
    }
    return value.toStringAsFixed(2);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.context,
  });

  final String title;
  final String value;
  final IconData icon;
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
      child: Row(
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
          (stat) => _BillerStatCard(stat: stat),
        ),
      ],
    );
  }
}

class _BillerStatCard extends StatelessWidget {
  const _BillerStatCard({required this.stat});

  final BillerStat stat;

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
    if (value >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(2)}M';
    } else if (value >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(2)}K';
    }
    return '\$${value.toStringAsFixed(2)}';
  }
}

