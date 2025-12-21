import 'package:bb_mobile/core/exchange/domain/entity/order_stats.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/statistics_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ExchangeStatisticsScreen extends StatelessWidget {
  const ExchangeStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => locator<StatisticsCubit>()..loadStats(),
      child: const _StatisticsView(),
    );
  }
}

class _StatisticsView extends StatelessWidget {
  const _StatisticsView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StatisticsCubit>().state;

    return Scaffold(
      backgroundColor: context.appColors.secondaryFixed,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.exchangeStatisticsTitle,
          onBack: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.hasError
                ? _buildErrorState(context, state.errorMessage!)
                : state.hasStats
                    ? _buildContent(context, state.orderStats!)
                    : _buildEmptyState(context),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: context.appColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<StatisticsCubit>().refresh(),
              child: Text(context.loc.recoverbullRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: context.appColors.outline,
          ),
          const SizedBox(height: 16),
          Text(
            context.loc.exchangeStatisticsNoData,
            style: context.font.bodyLarge?.copyWith(
              color: context.appColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, OrderStats stats) {
    return RefreshIndicator(
      onRefresh: () => context.read<StatisticsCubit>().refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLastUpdated(context, stats.asOf),
            const SizedBox(height: 24),
            _buildTradeCountSection(context, stats),
            const SizedBox(height: 24),
            _buildBuyVolumeSection(context, stats),
            const SizedBox(height: 24),
            _buildSellVolumeSection(context, stats),
            const SizedBox(height: 24),
            _buildAveragePricesSection(context, stats),
            if (stats.paidBillers.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildPaidBillersSection(context, stats),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLastUpdated(BuildContext context, DateTime asOf) {
    final formattedDate = DateFormat('MMM d, y \'at\' h:mm a').format(asOf);
    return Text(
      '${context.loc.exchangeStatisticsUpdatedAt}: $formattedDate',
      style: context.font.bodySmall?.copyWith(
        color: context.appColors.outline,
      ),
    );
  }

  Widget _buildTradeCountSection(BuildContext context, OrderStats stats) {
    return _StatCard(
      title: context.loc.exchangeStatisticsTradeCount,
      children: [
        _StatRow(
          label: context.loc.exchangeStatisticsBuyTrades,
          value: stats.buyTradeCount.toString(),
        ),
        _StatRow(
          label: context.loc.exchangeStatisticsSellTrades,
          value: stats.sellTradeCount.toString(),
        ),
        _StatRow(
          label: context.loc.exchangeStatisticsTotalTrades,
          value: stats.totalTradeCount.toString(),
          isTotal: true,
        ),
        _StatRow(
          label: context.loc.exchangeStatisticsBuySellRatio,
          value: stats.buySellRatio,
        ),
      ],
    );
  }

  Widget _buildBuyVolumeSection(BuildContext context, OrderStats stats) {
    if (stats.bitcoinBuyVolume.isEmpty) return const SizedBox.shrink();

    return _StatCard(
      title: context.loc.exchangeStatisticsBuyVolume,
      children: stats.bitcoinBuyVolume
          .map(
            (v) => _StatRow(
              label: v.currencyCode,
              value: v.formattedAmount,
            ),
          )
          .toList(),
    );
  }

  Widget _buildSellVolumeSection(BuildContext context, OrderStats stats) {
    if (stats.bitcoinSellVolume.isEmpty) return const SizedBox.shrink();

    return _StatCard(
      title: context.loc.exchangeStatisticsSellVolume,
      children: stats.bitcoinSellVolume
          .map(
            (v) => _StatRow(
              label: v.currencyCode,
              value: v.formattedAmount,
            ),
          )
          .toList(),
    );
  }

  Widget _buildAveragePricesSection(BuildContext context, OrderStats stats) {
    final hasBuyPrices = stats.averageBuyPrice.isNotEmpty;
    final hasSellPrices = stats.averageSellPrice.isNotEmpty;

    if (!hasBuyPrices && !hasSellPrices) return const SizedBox.shrink();

    return _StatCard(
      title: context.loc.exchangeStatisticsAveragePrice,
      children: [
        if (hasBuyPrices) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              context.loc.exchangeStatisticsBuyPrice,
              style: context.font.labelSmall?.copyWith(
                color: context.appColors.outline,
              ),
            ),
          ),
          ...stats.averageBuyPrice.map(
            (v) => _StatRow(
              label: v.currencyCode,
              value: v.formattedAmount,
            ),
          ),
        ],
        if (hasSellPrices) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              context.loc.exchangeStatisticsSellPrice,
              style: context.font.labelSmall?.copyWith(
                color: context.appColors.outline,
              ),
            ),
          ),
          ...stats.averageSellPrice.map(
            (v) => _StatRow(
              label: v.currencyCode,
              value: v.formattedAmount,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPaidBillersSection(BuildContext context, OrderStats stats) {
    return _StatCard(
      title: context.loc.exchangeStatisticsPaidBillers,
      children: stats.paidBillers
          .map(
            (b) => _StatRow(
              label: b.billerName,
              value:
                  '${b.orderCount} ${context.loc.exchangeStatisticsOrders} - ${b.totalAmount.toStringAsFixed(2)} ${b.currencyCode}',
            ),
          )
          .toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _StatCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.appColors.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.font.titleMedium?.copyWith(
              color: context.appColors.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _StatRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.secondary,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.primary,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

