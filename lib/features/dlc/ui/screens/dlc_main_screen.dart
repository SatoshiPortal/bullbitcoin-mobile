import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/core/dlc/domain/entities/dlc_instrument.dart';
import 'package:bb_mobile/core/dlc/domain/entities/dlc_order.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/auth/dlc_wallet_auth_cubit.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/connection/dlc_connection_cubit.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/contracts/dlc_contracts_cubit.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/instruments/dlc_instruments_cubit.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/my_orders/dlc_my_orders_cubit.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/orderbook/dlc_orderbook_cubit.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/place_order/dlc_place_order_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Main DLC screen with 4 tabs: Orderbook | Trade | My Activity | Status
class DlcMainScreen extends StatefulWidget {
  const DlcMainScreen({super.key});

  @override
  State<DlcMainScreen> createState() => _DlcMainScreenState();
}

class _DlcMainScreenState extends State<DlcMainScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Initialize auth and, if needed, show the opt-in dialog after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final authCubit = context.read<DlcWalletAuthCubit>();
      await authCubit.initialize();
      if (!mounted) return;
      final authState = authCubit.state;
      if (authState.needsDecision) {
        await _showOptInDialog();
      }
      // Load initial data only when registered (auth token is needed)
      if (!mounted) return;
      if (context.read<DlcWalletAuthCubit>().state.isRegistered) {
        _loadInitialData();
      } else {
        // Still load public (unauthenticated) data
        context.read<DlcConnectionCubit>().checkConnection();
        context.read<DlcInstrumentsCubit>().loadInstruments();
      }
    });
  }

  void _loadInitialData() {
    context.read<DlcConnectionCubit>().checkConnection();
    context.read<DlcInstrumentsCubit>().loadInstruments();
    context.read<DlcMyOrdersCubit>().loadMyOrders();
    context.read<DlcContractsCubit>().loadContracts();
  }

  Future<void> _showOptInDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DlcOptInDialog(),
    );
    if (!mounted) return;
    if (result == true) {
      await context.read<DlcWalletAuthCubit>().register();
      if (mounted &&
          context.read<DlcWalletAuthCubit>().state.isRegistered) {
        _loadInitialData();
      }
    } else {
      await context.read<DlcWalletAuthCubit>().optOut();
    }
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
        title: const Text('DLC Options'),
        actions: [
          // Connection health indicator
          BlocBuilder<DlcConnectionCubit, DlcConnectionState>(
            builder: (context, state) {
              final color = state.isHealthy
                  ? Colors.green
                  : state.connectionStatus == null
                      ? Colors.grey
                      : Colors.red;
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Tooltip(
                  message: 'API connection: ${state.connectionStatus?.apiHealth.name ?? 'unknown'}',
                  child: Icon(Icons.circle, color: color, size: 14),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt), text: 'Orderbook'),
            Tab(icon: Icon(Icons.swap_horiz), text: 'Trade'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Activity'),
            Tab(icon: Icon(Icons.health_and_safety), text: 'Status'),
          ],
        ),
      ),
      body: BlocBuilder<DlcWalletAuthCubit, DlcWalletAuthState>(
        buildWhen: (prev, curr) => prev.status != curr.status,
        builder: (context, authState) {
          if (authState.isOptedOut) {
            return _OptedOutPlaceholder(
              onEnable: () async {
                await context.read<DlcWalletAuthCubit>().signOut();
                if (mounted) await _showOptInDialog();
              },
            );
          }
          if (authState.isRegistering) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Registering wallet…'),
                ],
              ),
            );
          }
          if (authState.status == DlcWalletAuthStatus.failed) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 8),
                  Text(
                    'Registration failed:\n${authState.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      context.read<DlcWalletAuthCubit>().retryAfterFailure();
                      await _showOptInDialog();
                    },
                    child: const Text('Try again'),
                  ),
                ],
              ),
            );
          }
          return TabBarView(
            controller: _tabController,
            children: const [
              _OrderbookTab(),
              _TradeTab(),
              _ActivityTab(),
              _StatusTab(),
            ],
          );
        },
      ),
    );
  }
}

// ─── Opt-in dialog ────────────────────────────────────────────────────────────

class _DlcOptInDialog extends StatelessWidget {
  const _DlcOptInDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enable DLC Options'),
      content: const Text(
        'To participate in DLC Options trading, your wallet needs to be '
        'registered with the Bull Bitcoin DLC coordinator.\n\n'
        'This will use your wallet\'s public key to create an account. '
        'No funds are moved.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('No thanks'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Enable DLC Options'),
        ),
      ],
    );
  }
}

// ─── Opted-out placeholder ────────────────────────────────────────────────────

class _OptedOutPlaceholder extends StatelessWidget {
  const _OptedOutPlaceholder({required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.show_chart, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'DLC Options disabled',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'You opted out of DLC Options. Tap the button below to enable it.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: onEnable,
              child: const Text('Enable DLC Options'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Orderbook Tab ────────────────────────────────────────────────────────────

class _OrderbookTab extends StatelessWidget {
  const _OrderbookTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DlcInstrumentsCubit, DlcInstrumentsState>(
      builder: (context, instrumentsState) {
        if (instrumentsState.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (instrumentsState.instruments.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inbox, size: 48, color: Colors.grey),
                const SizedBox(height: 8),
                const Text('No instruments available'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      context.read<DlcInstrumentsCubit>().loadInstruments(),
                  child: const Text('Refresh'),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            _InstrumentSelector(
              instruments: instrumentsState.instruments,
              selected: instrumentsState.selectedInstrument,
              onSelected: (instrument) {
                context.read<DlcInstrumentsCubit>().selectInstrument(instrument);
                context
                    .read<DlcOrderbookCubit>()
                    .loadOrderbook(instrumentId: instrument.id);
              },
            ),
            const Expanded(child: _OrderbookList()),
          ],
        );
      },
    );
  }
}

class _InstrumentSelector extends StatelessWidget {
  const _InstrumentSelector({
    required this.instruments,
    required this.selected,
    required this.onSelected,
  });

  final List<DlcInstrument> instruments;
  final DlcInstrument? selected;
  final ValueChanged<DlcInstrument> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: instruments.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final instrument = instruments[index];
          final isSelected = instrument.id == selected?.id;
          return FilterChip(
            label: Text(instrument.name),
            selected: isSelected,
            onSelected: (_) => onSelected(instrument),
          );
        },
      ),
    );
  }
}

class _OrderbookList extends StatelessWidget {
  const _OrderbookList();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DlcOrderbookCubit, DlcOrderbookState>(
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
                  onPressed: () => context.read<DlcOrderbookCubit>().refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (state.orders.isEmpty) {
          if (state.selectedInstrumentId == null) {
            return const Center(child: Text('Select an instrument to view orders'));
          }
          return const Center(child: Text('No orders in the book'));
        }

        final buyOrders = state.buyOrders;
        final sellOrders = state.sellOrders;

        return RefreshIndicator(
          onRefresh: () => context.read<DlcOrderbookCubit>().refresh(),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (buyOrders.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Buy Orders',
                  color: Colors.green.shade700,
                ),
                ...buyOrders.map((o) => _OrderRow(order: o)),
                const SizedBox(height: 12),
              ],
              if (sellOrders.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Sell Orders',
                  color: Colors.red.shade700,
                ),
                ...sellOrders.map((o) => _OrderRow(order: o)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final DlcOrder order;

  @override
  Widget build(BuildContext context) {
    final isBuy = order.side == DlcOrderSide.buy;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: isBuy ? Colors.green.shade100 : Colors.red.shade100,
          child: Icon(
            isBuy ? Icons.arrow_upward : Icons.arrow_downward,
            size: 16,
            color: isBuy ? Colors.green.shade800 : Colors.red.shade800,
          ),
        ),
        title: Text(
          '${isBuy ? 'Buy' : 'Sell'} × ${order.quantity}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('Price: ${order.price} sats'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isBuy ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isBuy ? Colors.green.shade200 : Colors.red.shade200,
            ),
          ),
          child: Text(
            order.status,
            style: TextStyle(
              fontSize: 11,
              color: isBuy ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Trade Tab ────────────────────────────────────────────────────────────────

class _TradeTab extends StatelessWidget {
  const _TradeTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DlcInstrumentsCubit, DlcInstrumentsState>(
      builder: (context, instrumentsState) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Place Order',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              BlocBuilder<DlcPlaceOrderCubit, DlcPlaceOrderState>(
                builder: (context, state) {
                  if (state.isSuccess) {
                    return _OrderSuccessCard(
                      response: state.submittedOrderResponse!,
                      onReset: () => context.read<DlcPlaceOrderCubit>().reset(),
                    );
                  }
                  return _PlaceOrderForm(
                    instruments: instrumentsState.instruments,
                    selected: instrumentsState.selectedInstrument,
                    state: state,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlaceOrderForm extends StatefulWidget {
  const _PlaceOrderForm({
    required this.instruments,
    required this.selected,
    required this.state,
  });

  final List<DlcInstrument> instruments;
  final DlcInstrument? selected;
  final DlcPlaceOrderState state;

  @override
  State<_PlaceOrderForm> createState() => _PlaceOrderFormState();
}

class _PlaceOrderFormState extends State<_PlaceOrderForm> {
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DlcPlaceOrderCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Instrument selector
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Instrument',
            border: OutlineInputBorder(),
          ),
          value: widget.state.instrumentId,
          items: widget.instruments
              .map((i) => DropdownMenuItem(value: i.id, child: Text(i.name)))
              .toList(),
          onChanged: (val) {
            if (val != null) cubit.setInstrument(val);
          },
        ),
        const SizedBox(height: 12),
        // Buy / Sell toggle
        SegmentedButton<DlcOrderSide>(
          segments: const [
            ButtonSegment(value: DlcOrderSide.buy, label: Text('Buy')),
            ButtonSegment(value: DlcOrderSide.sell, label: Text('Sell')),
          ],
          selected: {widget.state.side},
          onSelectionChanged: (selection) => cubit.setSide(selection.first),
        ),
        const SizedBox(height: 12),
        // Price
        TextField(
          controller: _priceController,
          decoration: const InputDecoration(
            labelText: 'Price (sats)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onChanged: (val) {
            final parsed = int.tryParse(val);
            if (parsed != null) cubit.setPrice(parsed);
          },
        ),
        const SizedBox(height: 12),
        // Quantity
        TextField(
          controller: _quantityController,
          decoration: const InputDecoration(
            labelText: 'Quantity',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onChanged: (val) {
            final parsed = int.tryParse(val);
            if (parsed != null) cubit.setQuantity(parsed);
          },
        ),
        const SizedBox(height: 16),
        if (widget.state.error != null) ...[
          Text(
            'Error: ${widget.state.error}',
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton(
          onPressed: widget.state.isValid && !widget.state.isSubmitting
              ? () => cubit.submit()
              : null,
          child: widget.state.isSubmitting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Place Order'),
        ),
      ],
    );
  }
}

class _OrderSuccessCard extends StatelessWidget {
  const _OrderSuccessCard({required this.response, required this.onReset});

  final Map<String, dynamic> response;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  'Order Placed!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (response['order_id'] != null)
              _InfoRow(label: 'Order ID', value: response['order_id'].toString()),
            if (response['dlc_id'] != null)
              _InfoRow(label: 'DLC ID', value: response['dlc_id'].toString()),
            if (response['status'] != null)
              _InfoRow(label: 'Status', value: response['status'].toString()),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onReset,
              child: const Text('Place Another Order'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Activity Tab ─────────────────────────────────────────────────────────────

class _ActivityTab extends StatelessWidget {
  const _ActivityTab();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'My Orders'),
              Tab(text: 'My DLCs'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _MyOrdersView(),
                _MyDlcsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MyOrdersView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DlcMyOrdersCubit, DlcMyOrdersState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error: ${state.error}'),
                const SizedBox(height: 8),
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
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: state.orders.length,
            itemBuilder: (context, index) {
              final order = state.orders[index];
              return _MyOrderTile(order: order);
            },
          ),
        );
      },
    );
  }
}

class _MyOrderTile extends StatelessWidget {
  const _MyOrderTile({required this.order});

  final DlcOrder order;

  @override
  Widget build(BuildContext context) {
    final isBuy = order.side == DlcOrderSide.buy;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isBuy ? Colors.green.shade100 : Colors.red.shade100,
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
                'Signature required',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: order.isOpen
            ? IconButton(
                icon: const Icon(Icons.cancel_outlined),
                tooltip: 'Cancel order',
                onPressed: () => context
                    .read<DlcMyOrdersCubit>()
                    .cancelOrder(orderId: order.id),
              )
            : null,
      ),
    );
  }
}

class _MyDlcsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DlcContractsCubit, DlcContractsState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error: ${state.error}'),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => context.read<DlcContractsCubit>().refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (state.contracts.isEmpty) {
          return const Center(child: Text('No DLC contracts yet'));
        }
        return RefreshIndicator(
          onRefresh: () => context.read<DlcContractsCubit>().refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: state.contracts.length,
            itemBuilder: (context, index) {
              final contract = state.contracts[index];
              return _DlcContractTile(contract: contract);
            },
          ),
        );
      },
    );
  }
}

class _DlcContractTile extends StatelessWidget {
  const _DlcContractTile({required this.contract});

  final DlcContract contract;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: contract.isActive
              ? Colors.blue.shade100
              : Colors.grey.shade200,
          child: Icon(
            Icons.handshake_outlined,
            color: contract.isActive ? Colors.blue.shade800 : Colors.grey,
          ),
        ),
        title: Text(
          'DLC ${contract.id.length > 8 ? contract.id.substring(0, 8) : contract.id}...',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('Status: ${contract.status.name}'),
        trailing: Chip(
          label: Text(contract.status.name),
          backgroundColor: contract.isActive
              ? Colors.blue.shade50
              : Colors.grey.shade100,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

// ─── Status Tab ───────────────────────────────────────────────────────────────

class _StatusTab extends StatelessWidget {
  const _StatusTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DlcConnectionCubit, DlcConnectionState>(
      builder: (context, state) {
        return RefreshIndicator(
          onRefresh: () => context.read<DlcConnectionCubit>().checkConnection(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatusCard(state: state),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: state.isChecking
                    ? null
                    : () => context.read<DlcConnectionCubit>().checkConnection(),
                icon: state.isChecking
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Check Connection'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});

  final DlcConnectionState state;

  @override
  Widget build(BuildContext context) {
    final status = state.connectionStatus;
    final isHealthy = state.isHealthy;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isHealthy ? Icons.check_circle : Icons.error,
                  color: isHealthy ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  isHealthy ? 'Connected' : 'Not Connected',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isHealthy ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
              ],
            ),
            if (status != null) ...[
              const Divider(height: 24),
              _StatusRow(
                label: 'Health',
                value: status.apiHealth.name,
              ),
              if (status.latencyMs != null)
                _StatusRow(
                  label: 'Latency',
                  value: '${status.latencyMs} ms',
                ),
              if (status.engineVersion != null)
                _StatusRow(
                  label: 'Version',
                  value: status.engineVersion!,
                ),
              if (status.lastCheckedAt != null)
                _StatusRow(
                  label: 'Last checked',
                  value: status.lastCheckedAt!,
                ),
              if (status.message != null)
                _StatusRow(
                  label: 'Message',
                  value: status.message!,
                ),
            ] else ...[
              const SizedBox(height: 8),
              const Text(
                'No connection data. Tap "Check Connection" to test.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
