import 'package:bb_mobile/core/dlc/domain/entities/dlc_order.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/orderbook/dlc_orderbook_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Standalone orderbook screen (used for navigation from DLC home).
/// For the main tabbed experience, see DlcMainScreen.
class DlcOrderbookScreen extends StatefulWidget {
  const DlcOrderbookScreen({super.key, required this.instrumentId});

  final String instrumentId;

  @override
  State<DlcOrderbookScreen> createState() => _DlcOrderbookScreenState();
}

class _DlcOrderbookScreenState extends State<DlcOrderbookScreen> {
  @override
  void initState() {
    super.initState();
    context.read<DlcOrderbookCubit>().loadOrderbook(instrumentId: widget.instrumentId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Orderbook: ${widget.instrumentId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<DlcOrderbookCubit>().refresh(),
          ),
        ],
      ),
      body: BlocBuilder<DlcOrderbookCubit, DlcOrderbookState>(
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
                  Text('Failed to load orderbook: ${state.error}'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.read<DlcOrderbookCubit>().refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (state.orders.isEmpty) {
            return const Center(child: Text('No orders in the book'));
          }
          return RefreshIndicator(
            onRefresh: () => context.read<DlcOrderbookCubit>().refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.orders.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final order = state.orders[index];
                return _OrderbookRow(order: order);
              },
            ),
          );
        },
      ),
    );
  }
}

class _OrderbookRow extends StatelessWidget {
  const _OrderbookRow({required this.order});

  final DlcOrder order;

  @override
  Widget build(BuildContext context) {
    final isBuy = order.side == DlcOrderSide.buy;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isBuy ? Colors.green.shade100 : Colors.red.shade100,
        child: Icon(
          isBuy ? Icons.arrow_upward : Icons.arrow_downward,
          color: isBuy ? Colors.green.shade800 : Colors.red.shade800,
        ),
      ),
      title: Text(
        '${isBuy ? 'Buy' : 'Sell'} × ${order.quantity}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('Price: ${order.price} sats'),
      trailing: Chip(
        label: Text(order.status),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
