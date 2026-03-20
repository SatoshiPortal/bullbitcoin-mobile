import 'package:bb_mobile/features/dlc/presentation/bloc/connection/dlc_connection_cubit.dart';
import 'package:bb_mobile/features/dlc/ui/dlc_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class DlcHomeScreen extends StatelessWidget {
  const DlcHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DLC Options'),
        actions: [
          BlocBuilder<DlcConnectionCubit, DlcConnectionState>(
            builder: (context, state) {
              final color = state.isHealthy
                  ? Colors.green
                  : state.connectionStatus == null
                      ? Colors.grey
                      : Colors.red;
              return IconButton(
                icon: Icon(Icons.circle, color: color, size: 14),
                tooltip: 'API connection status',
                onPressed: () => context.push(DlcRoute.connection.path),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DlcMenuCard(
            icon: Icons.list_alt,
            title: 'Orderbook',
            subtitle: 'Browse open call and put orders',
            onTap: () => context.push(DlcRoute.orderbook.path),
          ),
          const SizedBox(height: 12),
          _DlcMenuCard(
            icon: Icons.receipt_long,
            title: 'My Orders',
            subtitle: 'View and manage your open orders',
            onTap: () => context.push(DlcRoute.myOrders.path),
          ),
          const SizedBox(height: 12),
          _DlcMenuCard(
            icon: Icons.add_circle_outline,
            title: 'Place Order',
            subtitle: 'Enter a new call or put option',
            onTap: () => context.push(DlcRoute.placeOrder.path),
          ),
          const SizedBox(height: 12),
          _DlcMenuCard(
            icon: Icons.health_and_safety,
            title: 'Engine Status',
            subtitle: 'Check DLC API connection health',
            onTap: () => context.push(DlcRoute.connection.path),
          ),
        ],
      ),
    );
  }
}

class _DlcMenuCard extends StatelessWidget {
  const _DlcMenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
