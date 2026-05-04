import 'package:bb_mobile/features/pos/pos_router.dart';
import 'package:bb_mobile/features/pos/presentation/bloc/pos_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PosHomeScreen extends StatelessWidget {
  const PosHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosCubit, PosState>(
      builder: (context, state) {
        final identity = state.identity;
        final liveTerminals = state.terminals
            .where((terminal) => !terminal.isRevoked)
            .length;
        return Scaffold(
          appBar: AppBar(title: const Text('Point of Sale')),
          body: RefreshIndicator(
            onRefresh: () => context.read<PosCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (state.error != null)
                  _Banner(text: state.error!, icon: Icons.error_outline),
                if (state.isLoading) const LinearProgressIndicator(),
                ListTile(
                  leading: Icon(
                    identity == null
                        ? Icons.point_of_sale_outlined
                        : Icons.store,
                  ),
                  title: Text(identity == null ? 'Not set up' : identity.name),
                  subtitle: Text(
                    identity == null
                        ? 'Create a merchant profile to pair cashier terminals.'
                        : 'Live on ${identity.network.name}, $liveTerminals terminals paired',
                  ),
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.tune,
                  title: identity == null ? 'Setup' : 'Profile',
                  onTap: () => context.pushNamed(PosRoute.setup.name),
                ),
                _ActionTile(
                  icon: Icons.qr_code_scanner,
                  title: 'Pair Terminal',
                  enabled: identity != null,
                  onTap: () => context.pushNamed(PosRoute.pair.name),
                ),
                _ActionTile(
                  icon: Icons.receipt_long,
                  title: 'Sales',
                  enabled: identity != null,
                  onTap: () => context.pushNamed(PosRoute.sales.name),
                ),
                _ActionTile(
                  icon: Icons.devices_other,
                  title: 'Terminals',
                  enabled: identity != null,
                  onTap: () => context.pushNamed(PosRoute.terminals.name),
                ),
                _ActionTile(
                  icon: Icons.health_and_safety,
                  title: 'Recovery',
                  enabled: identity != null,
                  onTap: () => context.pushNamed(PosRoute.recovery.name),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: enabled,
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: enabled ? onTap : null,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(text),
      tileColor: Theme.of(context).colorScheme.errorContainer,
    );
  }
}
