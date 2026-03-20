import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/core/dlc/domain/entities/dlc_order.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/my_orders/dlc_my_orders_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Temporary stub pubkey — will be replaced with the real wallet pubkey.
const _stubPubkey = 'stub_pubkey';

class DlcMyOrdersScreen extends StatefulWidget {
  const DlcMyOrdersScreen({super.key});

  @override
  State<DlcMyOrdersScreen> createState() => _DlcMyOrdersScreenState();
}

class _DlcMyOrdersScreenState extends State<DlcMyOrdersScreen> {
  @override
  void initState() {
    super.initState();
    context
        .read<DlcMyOrdersCubit>()
        .loadMyOrders(pubkey: _stubPubkey);
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
                    onPressed: () => context
                        .read<DlcMyOrdersCubit>()
                        .refresh(pubkey: _stubPubkey),
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
            onRefresh: () => context
                .read<DlcMyOrdersCubit>()
                .refresh(pubkey: _stubPubkey),
            child: CustomScrollView(
              slivers: [
                if (state.openOrders.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: _SectionHeader(title: 'Open'),
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
                if (state.closedOrders.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: _SectionHeader(title: 'Closed / Filled'),
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
        content: Text(
          'Cancel ${order.optionType.name} order #${order.id.substring(0, 8)}…?',
        ),
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
      // TODO: replace with real signature from wallet key
      context.read<DlcMyOrdersCubit>().cancelOrder(
            orderId: order.id,
            makerPubkey: _stubPubkey,
            signatureHex: 'stub_signature',
          );
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
  });

  final DlcOrder order;
  final bool isCancelling;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final isCall = order.optionType == DlcOptionType.call;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isCall ? Colors.green.shade100 : Colors.red.shade100,
        child: Text(
          isCall ? 'C' : 'P',
          style: TextStyle(
            color: isCall ? Colors.green.shade800 : Colors.red.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        '${isCall ? 'Call' : 'Put'} @ ${order.strikePriceSat} sats',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${order.side.name.toUpperCase()} · '
        'qty ${order.remainingQuantity}/${order.quantity} · '
        '${order.premiumSat} sats premium',
      ),
      trailing: order.isOpen && onCancel != null
          ? isCancelling
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  tooltip: 'Cancel order',
                  onPressed: onCancel,
                )
          : Chip(
              label: Text(order.status.name),
              visualDensity: VisualDensity.compact,
            ),
    );
  }
}
