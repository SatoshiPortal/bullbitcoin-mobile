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
              _OrderStatsSection(state: state),
              const SizedBox(height: 24),
              if (state.billerStats != null && state.billerStats!.hasStats)
                _BillerStatsSection(state: state),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderStatsSection extends StatelessWidget {
  const _OrderStatsSection({
    required this.state,
  });

  final StatisticsState state;

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
          value: state.orderStats?.buySellRatio ?? '',
          icon: Icons.compare_arrows,
        ),
        const SizedBox(height: 12),
        _StatSectionCard(
          title: context.loc.exchangeStatisticsBuyStats,
          icon: Icons.arrow_downward,
          iconColor: Colors.green,
          stats: [
            _StatRow(
              label: context.loc.exchangeStatisticsVolume,
              values: state.formattedBuyVolume,
              description: context.loc.exchangeStatisticsBuyVolumeDesc,
            ),
            _StatRow(
              label: context.loc.exchangeStatisticsTradeCount,
              values: state.formattedBuyTradeCount,
              description: context.loc.exchangeStatisticsBuyTradeCountDesc,
            ),
            _StatRow(
              label: context.loc.exchangeStatisticsAveragePrice,
              values: state.formattedAvgBuyPrice,
              description: context.loc.exchangeStatisticsBuyAvgPriceDesc,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _StatSectionCard(
          title: context.loc.exchangeStatisticsSellStats,
          icon: Icons.arrow_upward,
          iconColor: Colors.red,
          stats: [
            _StatRow(
              label: context.loc.exchangeStatisticsVolume,
              values: state.formattedSellVolume,
              description: context.loc.exchangeStatisticsSellVolumeDesc,
            ),
            _StatRow(
              label: context.loc.exchangeStatisticsTradeCount,
              values: state.formattedSellTradeCount,
              description: context.loc.exchangeStatisticsSellTradeCountDesc,
            ),
            _StatRow(
              label: context.loc.exchangeStatisticsAveragePrice,
              values: state.formattedAvgSellPrice,
              description: context.loc.exchangeStatisticsSellAvgPriceDesc,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MultiValueStatCard(
          title: context.loc.exchangeStatisticsTotalVolume,
          description: context.loc.exchangeStatisticsTotalVolumeDesc,
          values: state.formattedTotalVolume,
          icon: Icons.trending_up,
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.values,
    this.description,
  });

  final String label;
  final List<String> values;
  final String? description;

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: values
                .map(
                  (value) => BBText(
                    value,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.description,
  });

  final String title;
  final String value;
  final IconData icon;
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

class _MultiValueStatCard extends StatelessWidget {
  const _MultiValueStatCard({
    required this.title,
    required this.values,
    required this.icon,
    this.description,
  });

  final String title;
  final List<String> values;
  final IconData icon;
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
                ...values.map(
                  (value) => BBText(
                    value,
                    style: context.font.headlineSmall?.copyWith(
                      color: context.appColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
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
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> stats;

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
  const _BillerStatsSection({required this.state});

  final StatisticsState state;

  @override
  Widget build(BuildContext context) {
    final billerStats = state.billerStats;
    if (billerStats == null) return const SizedBox.shrink();

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
        ...state.formattedBillerStats.map(
          (stat) => _BillerStatCard(stat: stat),
        ),
      ],
    );
  }
}

class _BillerStatCard extends StatelessWidget {
  const _BillerStatCard({
    required this.stat,
  });

  final FormattedBillerStat stat;

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
                  stat.formattedAmount,
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
}
