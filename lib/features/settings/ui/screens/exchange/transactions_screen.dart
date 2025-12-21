import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/exchange_transactions_cubit.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/exchange_transactions_state.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ExchangeTransactionsScreen extends StatelessWidget {
  const ExchangeTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => locator<ExchangeTransactionsCubit>()..loadOrders(),
      child: const _TransactionsView(),
    );
  }
}

class _TransactionsView extends StatelessWidget {
  const _TransactionsView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ExchangeTransactionsCubit>().state;

    return Scaffold(
      backgroundColor: context.appColors.secondaryFixed,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.exchangeTransactionsTitle,
          onBack: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildFilterBar(context, state),
            Expanded(
              child: state.isLoading && state.orders.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : state.hasError
                      ? _buildErrorState(context, state.errorMessage!)
                      : state.hasOrders
                          ? _buildOrdersList(context, state)
                          : _buildEmptyState(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    ExchangeTransactionsState state,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: context.loc.transactionFilterAll,
              isSelected: state.filterType == null,
              onSelected: () =>
                  context.read<ExchangeTransactionsCubit>().setFilterType(null),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: context.loc.transactionFilterBuy,
              isSelected: state.filterType == OrderType.buy,
              onSelected: () => context
                  .read<ExchangeTransactionsCubit>()
                  .setFilterType(OrderType.buy),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: context.loc.transactionFilterSell,
              isSelected: state.filterType == OrderType.sell,
              onSelected: () => context
                  .read<ExchangeTransactionsCubit>()
                  .setFilterType(OrderType.sell),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: context.loc.transactionFilterTransfer,
              isSelected: state.filterType == OrderType.withdraw,
              onSelected: () => context
                  .read<ExchangeTransactionsCubit>()
                  .setFilterType(OrderType.withdraw),
            ),
          ],
        ),
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
              onPressed: () =>
                  context.read<ExchangeTransactionsCubit>().refresh(),
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
            Icons.receipt_long,
            size: 64,
            color: context.appColors.outline,
          ),
          const SizedBox(height: 16),
          Text(
            context.loc.transactionListNoTransactions,
            style: context.font.bodyLarge?.copyWith(
              color: context.appColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(
    BuildContext context,
    ExchangeTransactionsState state,
  ) {
    final orders = state.filteredOrders;

    return RefreshIndicator(
      onRefresh: () => context.read<ExchangeTransactionsCubit>().refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length + (state.hasMorePages ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == orders.length) {
            // Load more indicator
            if (!state.isLoading) {
              context.read<ExchangeTransactionsCubit>().loadNextPage();
            }
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final order = orders[index];
          return _OrderCard(order: order);
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: context.appColors.primary.withOpacity(0.2),
      checkmarkColor: context.appColors.primary,
      labelStyle: TextStyle(
        color: isSelected
            ? context.appColors.primary
            : context.appColors.secondary,
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, y');
    final (amount, currency) = order.amountAndCurrencyToDisplay();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildOrderTypeIcon(context),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderType.value,
                        style: context.font.titleSmall?.copyWith(
                          color: context.appColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '#${order.orderNumber}',
                        style: context.font.bodySmall?.copyWith(
                          color: context.appColors.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${order.isIncoming ? '+' : '-'}${amount is double ? amount.toStringAsFixed(0) : amount} $currency',
                    style: context.font.titleSmall?.copyWith(
                      color: order.isIncoming
                          ? context.appColors.primary
                          : context.appColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    dateFormat.format(order.createdAt),
                    style: context.font.bodySmall?.copyWith(
                      color: context.appColors.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatusRow(context),
        ],
      ),
    );
  }

  Widget _buildOrderTypeIcon(BuildContext context) {
    IconData iconData;
    Color iconColor;

    switch (order.orderType) {
      case OrderType.buy:
        iconData = Icons.arrow_downward;
        iconColor = context.appColors.primary;
      case OrderType.sell:
        iconData = Icons.arrow_upward;
        iconColor = context.appColors.error;
      case OrderType.withdraw:
        iconData = Icons.account_balance;
        iconColor = context.appColors.tertiary;
      case OrderType.funding:
        iconData = Icons.add_circle;
        iconColor = context.appColors.primary;
      default:
        iconData = Icons.swap_horiz;
        iconColor = context.appColors.secondary;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 20,
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context) {
    Color statusColor;
    String statusText = order.orderStatus.value;

    if (order.isCompleted()) {
      statusColor = context.appColors.primary;
    } else if (order.isCancelled() || order.isExpired()) {
      statusColor = context.appColors.error;
    } else {
      statusColor = context.appColors.tertiary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        statusText,
        style: context.font.labelSmall?.copyWith(
          color: statusColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
