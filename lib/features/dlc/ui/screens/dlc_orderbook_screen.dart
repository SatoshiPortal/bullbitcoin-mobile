import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/core/dlc/domain/entities/dlc_order.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/orderbook/dlc_orderbook_cubit.dart';
import 'package:bb_mobile/features/dlc/ui/dlc_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class DlcOrderbookScreen extends StatefulWidget {
  const DlcOrderbookScreen({super.key});

  @override
  State<DlcOrderbookScreen> createState() => _DlcOrderbookScreenState();
}

class _DlcOrderbookScreenState extends State<DlcOrderbookScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<DlcOrderbookCubit>().loadOrderbook();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orderbook'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<DlcOrderbookCubit>().refresh(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            final cubit = context.read<DlcOrderbookCubit>();
            switch (index) {
              case 0:
                cubit.setFilter(null);
              case 1:
                cubit.setFilter(DlcOptionType.call);
              case 2:
                cubit.setFilter(DlcOptionType.put);
            }
          },
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Calls'),
            Tab(text: 'Puts'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(DlcRoute.placeOrder.path),
        icon: const Icon(Icons.add),
        label: const Text('Place Order'),
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
                    onPressed: () =>
                        context.read<DlcOrderbookCubit>().refresh(),
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
    final isCall = order.optionType == DlcOptionType.call;
    final isBuy = order.side == DlcOrderSide.buy;
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
        '${isBuy ? 'Buy' : 'Sell'} · qty ${order.remainingQuantity}/${order.quantity} · '
        '${order.premiumSat} sats premium',
      ),
      trailing: Chip(
        label: Text(order.status.name),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

