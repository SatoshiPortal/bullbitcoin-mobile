import 'package:bb_mobile/core/dlc/domain/entities/dlc_connection_status.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/connection/dlc_connection_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DlcConnectionScreen extends StatefulWidget {
  const DlcConnectionScreen({super.key});

  @override
  State<DlcConnectionScreen> createState() => _DlcConnectionScreenState();
}

class _DlcConnectionScreenState extends State<DlcConnectionScreen> {
  @override
  void initState() {
    super.initState();
    context.read<DlcConnectionCubit>().checkConnection();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DLC Engine Status')),
      body: BlocBuilder<DlcConnectionCubit, DlcConnectionState>(
        builder: (context, state) {
          if (state.isChecking) {
            return const Center(child: CircularProgressIndicator());
          }

          final status = state.connectionStatus;
          if (status == null) {
            return const Center(child: Text('No status yet'));
          }

          return RefreshIndicator(
            onRefresh: () => context.read<DlcConnectionCubit>().checkConnection(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StatusCard(status: status),
                const SizedBox(height: 16),
                if (status.engineVersion != null)
                  _InfoRow(label: 'Engine version', value: status.engineVersion!),
                if (status.latencyMs != null)
                  _InfoRow(
                    label: 'Latency',
                    value: '${status.latencyMs} ms',
                  ),
                if (status.message != null)
                  _InfoRow(label: 'Message', value: status.message!),
                if (status.lastCheckedAt != null)
                  _InfoRow(label: 'Last checked', value: status.lastCheckedAt!),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () =>
                      context.read<DlcConnectionCubit>().checkConnection(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check again'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final DlcConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (status.apiHealth) {
      DlcApiHealth.healthy => (Colors.green, Icons.check_circle, 'Healthy'),
      DlcApiHealth.degraded => (Colors.orange, Icons.warning, 'Degraded'),
      DlcApiHealth.unreachable => (Colors.red, Icons.error, 'Unreachable'),
      DlcApiHealth.unknown => (Colors.grey, Icons.help, 'Unknown'),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color, size: 36),
        title: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        subtitle: const Text('DLC Engine API'),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }
}
