import 'package:bb_mobile/core/exchange/domain/entity/order_stats.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/statistics_cubit.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/statistics_state.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/exchange_settings_failure_l10n.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<StatisticsCubit>().loadStatistics();
  }

  @override
  Widget build(BuildContext context) {
    return BullScaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: BullTopBar(
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
        BullFadingLinearProgress(
          trigger: state.isLoading,
          backgroundColor: context.bull.surface,
          foregroundColor: context.bull.primary,
        ),
        Expanded(child: _buildContent(context, state)),
      ],
    );
  }

  Widget _buildContent(BuildContext context, StatisticsState state) {
    if (state.isLoading && !state.hasStats) {
      return const SizedBox.shrink();
    }

    if (state.failure != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BullText(
              state.failure!.toTranslated(context),
              style: context.bullText.bodyMedium?.copyWith(
                color: context.bull.error,
              ),
            ),
            const Gap(BullSpacing.md),
            BullButton.big(
              label: context.loc.retry,
              onPressed: () => context.read<StatisticsCubit>().loadStatistics(),
              bgColor: context.bull.onSurface,
              textColor: context.bull.surface,
            ),
          ],
        ),
      );
    }

    if (!state.hasStats) {
      return Center(
        child: BullText(
          context.loc.exchangeStatisticsNoData,
          style: context.bullText.bodyMedium?.copyWith(
            color: context.bull.outline,
          ),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(BullSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.asOf != null) ...[
                BullText(
                  context.loc.exchangeStatisticsAsOf(
                    DateFormat('MMM d, yyyy HH:mm').format(state.asOf!),
                  ),
                  style: context.bullText.bodySmall?.copyWith(
                    color: context.bull.outline,
                  ),
                ),
                const Gap(BullSpacing.md),
              ],
              _OrderStatsSection(state: state),
              const Gap(BullSpacing.lg),
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
  const _OrderStatsSection({required this.state});

  final StatisticsState state;

  List<String> _tradeCounts(
    BuildContext context,
    List<AmountByCurrencyCode> counts,
  ) {
    if (counts.isEmpty) {
      return [context.loc.exchangeStatisticsTradeCountValue(0)];
    }

    return counts
        .map(
          (c) => context.loc.exchangeStatisticsTradeCountByCurrency(
            c.value.toInt(),
            c.currency,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BullText(
          context.loc.exchangeStatisticsOrderStats,
          style: context.bullText.headlineMedium?.copyWith(
            color: context.bull.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Gap(BullSpacing.md),
        _MultiValueStatCard(
          title: context.loc.exchangeStatisticsBuySellRatio,
          description: context.loc.exchangeStatisticsBuySellRatioDesc,
          values: [state.orderStats?.buySellRatio ?? ''],
          icon: Icons.compare_arrows,
        ),
        const Gap(BullSpacing.sm),
        _StatSectionCard(
          title: context.loc.exchangeStatisticsBuyStats,
          icon: Icons.arrow_downward,
          iconColor: context.bull.success,
          stats: [
            _StatRow(
              label: context.loc.exchangeStatisticsVolume,
              values: state.formattedBuyVolume,
              description: context.loc.exchangeStatisticsBuyVolumeDesc,
            ),
            _StatRow(
              label: context.loc.exchangeStatisticsTradeCount,
              values: _tradeCounts(context, state.buyTradeCounts),
              description: context.loc.exchangeStatisticsBuyTradeCountDesc,
            ),
            _StatRow(
              label: context.loc.exchangeStatisticsAveragePrice,
              values: state.formattedAvgBuyPrice,
              description: context.loc.exchangeStatisticsBuyAvgPriceDesc,
            ),
          ],
        ),
        const Gap(BullSpacing.sm),
        _StatSectionCard(
          title: context.loc.exchangeStatisticsSellStats,
          icon: Icons.arrow_upward,
          iconColor: context.bull.error,
          stats: [
            _StatRow(
              label: context.loc.exchangeStatisticsVolume,
              values: state.formattedSellVolume,
              description: context.loc.exchangeStatisticsSellVolumeDesc,
            ),
            _StatRow(
              label: context.loc.exchangeStatisticsTradeCount,
              values: _tradeCounts(context, state.sellTradeCounts),
              description: context.loc.exchangeStatisticsSellTradeCountDesc,
            ),
            _StatRow(
              label: context.loc.exchangeStatisticsAveragePrice,
              values: state.formattedAvgSellPrice,
              description: context.loc.exchangeStatisticsSellAvgPriceDesc,
            ),
          ],
        ),
        const Gap(BullSpacing.sm),
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

class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({required this.child, this.margin});

  final Widget child;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.all(BullSpacing.md),
      decoration: BoxDecoration(
        color: context.bull.surface,
        borderRadius: BorderRadius.circular(BullRadius.sm),
        boxShadow: [
          BoxShadow(
            color: context.bull.overlay.withValues(alpha: 0.05),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.values, this.description});

  final String label;
  final List<String> values;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BullSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BullText(
                  label,
                  style: context.bullText.bodyMedium?.copyWith(
                    color: context.bull.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (description != null) ...[
                  const Gap(2),
                  BullText(
                    description!,
                    style: context.bullText.bodySmall?.copyWith(
                      color: context.bull.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Gap(BullSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: values
                .map(
                  (value) => BullText(
                    value,
                    style: context.bullText.bodyMedium?.copyWith(
                      color: context.bull.onSurface,
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
    return _StatisticsCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.bull.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(BullRadius.sm),
            ),
            child: Icon(icon, color: context.bull.primary, size: 24),
          ),
          const Gap(BullSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BullText(
                  title,
                  style: context.bullText.bodySmall?.copyWith(
                    color: context.bull.textMuted,
                  ),
                ),
                const Gap(BullSpacing.xxs),
                ...values.map(
                  (value) => BullText(
                    value,
                    style: context.bullText.headlineSmall?.copyWith(
                      color: context.bull.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (description != null) ...[
                  const Gap(6),
                  BullText(
                    description!,
                    style: context.bullText.bodySmall?.copyWith(
                      color: context.bull.textMuted,
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
    return _StatisticsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const Gap(BullSpacing.xs),
              BullText(
                title,
                style: context.bullText.labelLarge?.copyWith(
                  color: context.bull.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Gap(BullSpacing.sm),
          const Divider(height: 1),
          const Gap(BullSpacing.sm),
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
        BullText(
          context.loc.exchangeStatisticsBillerStats,
          style: context.bullText.headlineMedium?.copyWith(
            color: context.bull.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (billerStats.currency.isNotEmpty)
          BullText(
            context.loc.exchangeStatisticsCurrency(billerStats.currency),
            style: context.bullText.bodySmall?.copyWith(
              color: context.bull.textMuted,
            ),
          ),
        const Gap(BullSpacing.md),
        ...state.formattedBillerStats.map(
          (stat) => _BillerStatCard(stat: stat),
        ),
      ],
    );
  }
}

class _BillerStatCard extends StatelessWidget {
  const _BillerStatCard({required this.stat});

  final FormattedBillerStat stat;

  @override
  Widget build(BuildContext context) {
    return _StatisticsCard(
      margin: const EdgeInsets.only(bottom: BullSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BullText(
            stat.displayName,
            style: context.bullText.labelLarge?.copyWith(
              color: context.bull.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(BullSpacing.sm),
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
        BullText(
          label,
          style: context.bullText.bodySmall?.copyWith(
            color: context.bull.textMuted,
          ),
        ),
        const Gap(BullSpacing.xxs),
        BullText(
          value,
          style: context.bullText.bodyMedium?.copyWith(
            color: context.bull.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
