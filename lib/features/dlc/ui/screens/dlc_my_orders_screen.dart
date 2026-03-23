import 'package:bb_mobile/core/dlc/domain/entities/dlc_order.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/sign_and_submit_cets_usecase.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/my_orders/dlc_my_orders_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DlcMyOrdersScreen extends StatefulWidget {
  const DlcMyOrdersScreen({super.key});

  @override
  State<DlcMyOrdersScreen> createState() => _DlcMyOrdersScreenState();
}

class _DlcMyOrdersScreenState extends State<DlcMyOrdersScreen> {
  @override
  void initState() {
    super.initState();
    context.read<DlcMyOrdersCubit>().loadMyOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: BlocBuilder<DlcMyOrdersCubit, DlcMyOrdersState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 8),
                  Text('Error: ${state.error}'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.read<DlcMyOrdersCubit>().refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (state.orders.isEmpty) {
            return const Center(child: Text('No orders yet'));
          }
          return RefreshIndicator(
            onRefresh: () => context.read<DlcMyOrdersCubit>().refresh(),
            child: CustomScrollView(
              slivers: [
                if (state.openOrders.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: _SectionHeader(title: 'Open / Pending'),
                  ),
                  SliverList.separated(
                    itemCount: state.openOrders.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) => _MyOrderRow(
                      order: state.openOrders[index],
                      isCancelling: state.cancellingIds
                          .contains(state.openOrders[index].id),
                      onCancel: () => _confirmCancel(
                        context,
                        state.openOrders[index],
                      ),
                    ),
                  ),
                ],
                if (state.matchedOrders.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: _SectionHeader(title: 'Matched'),
                  ),
                  SliverList.separated(
                    itemCount: state.matchedOrders.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final order = state.matchedOrders[index];
                      final isSigning = state.signingOrderId == order.id;
                      if (isSigning) {
                        return _TakerSigningProgress(
                          signingStep: state.signingStep,
                          order: order,
                        );
                      }
                      return _MyOrderRow(
                        order: order,
                        isCancelling: false,
                        onCancel: null,
                        onSign: order.needsSignature &&
                                state.signingOrderId == null
                            ? () => context
                                .read<DlcMyOrdersCubit>()
                                .signAndSubmitTaker(orderId: order.id)
                            : null,
                      );
                    },
                  ),
                ],
                if (state.closedOrders.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: _SectionHeader(title: 'Cancelled'),
                  ),
                  SliverList.separated(
                    itemCount: state.closedOrders.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) => _MyOrderRow(
                      order: state.closedOrders[index],
                      isCancelling: false,
                      onCancel: null,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, DlcOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel order?'),
        content: Text('Cancel order #${order.id.length >= 8 ? order.id.substring(0, 8) : order.id}…?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<DlcMyOrdersCubit>().cancelOrder(orderId: order.id);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _MyOrderRow extends StatelessWidget {
  const _MyOrderRow({
    required this.order,
    required this.isCancelling,
    required this.onCancel,
    this.onSign,
  });

  final DlcOrder order;
  final bool isCancelling;
  final VoidCallback? onCancel;
  final VoidCallback? onSign;

  @override
  Widget build(BuildContext context) {
    final isBuy = order.side == DlcOrderSide.buy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor:
                isBuy ? Colors.green.shade100 : Colors.red.shade100,
            child: Icon(
              isBuy ? Icons.arrow_upward : Icons.arrow_downward,
              color: isBuy ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
          title: Text(
            '${isBuy ? 'Buy' : 'Sell'} × ${order.quantity} @ ${order.price} sats',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: ${order.status}'),
              if (order.dlcId != null) Text('DLC: ${order.dlcId}'),
              if (order.needsSignature)
                Text(
                  'Your signature is required',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          isThreeLine: order.dlcId != null || order.needsSignature,
          trailing: order.isOpen && onCancel != null
              ? isCancelling
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.cancel_outlined,
                          color: Colors.red),
                      tooltip: 'Cancel order',
                      onPressed: onCancel,
                    )
              : Chip(
                  label: Text(order.status),
                  visualDensity: VisualDensity.compact,
                ),
        ),
        if (onSign != null)
          Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: FilledButton.icon(
              onPressed: onSign,
              icon: const Icon(Icons.draw, size: 18),
              label: const Text('Sign & Accept'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
              ),
            ),
          ),
      ],
    );
  }
}

/// Shown in place of a matched order row while taker signing is in progress.
class _TakerSigningProgress extends StatelessWidget {
  const _TakerSigningProgress({
    required this.signingStep,
    required this.order,
  });

  final DlcSigningStep? signingStep;
  final DlcOrder order;

  static const _steps = [
    (DlcSigningStep.preparingKey, 'Preparing wallet key'),
    (DlcSigningStep.fetchingContext, 'Fetching accept context'),
    (DlcSigningStep.signing, 'Signing transactions'),
    (DlcSigningStep.submitting, 'Submitting to coordinator'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = signingStep == null
        ? -1
        : _steps.indexWhere((s) => s.$1 == signingStep);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Signing order ${order.id.length >= 8 ? order.id.substring(0, 8) : order.id}…',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < _steps.length; i++)
                _MiniStepRow(
                  label: _steps[i].$2,
                  isDone: i < currentIndex,
                  isActive: i == currentIndex,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStepRow extends StatelessWidget {
  const _MiniStepRow({
    required this.label,
    required this.isDone,
    required this.isActive,
  });

  final String label;
  final bool isDone;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isDone
        ? Theme.of(context).colorScheme.primary
        : isActive
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.outlineVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight:
                  isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (isActive) ...[
            const SizedBox(width: 6),
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
