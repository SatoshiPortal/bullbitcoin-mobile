import 'package:bb_mobile/features/pos/presentation/bloc/pos_cubit.dart';
import 'package:bb_mobile/features/pos/presentation/bloc/pos_recovery_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PosRecoveryScreen extends StatelessWidget {
  const PosRecoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosRecoveryCubit, PosRecoveryState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('POS Recovery')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (state.isLoading) const LinearProgressIndicator(),
              if (state.error != null)
                ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(state.error!),
                ),
              FilledButton.icon(
                icon: const Icon(Icons.health_and_safety),
                label: const Text('Scan and Recover'),
                onPressed: state.isLoading
                    ? null
                    : () {
                        final identity = context
                            .read<PosCubit>()
                            .state
                            .identity;
                        if (identity != null) {
                          context.read<PosRecoveryCubit>().run(identity.ref);
                        }
                      },
              ),
              const SizedBox(height: 16),
              if (state.results.isEmpty && !state.isLoading)
                const ListTile(
                  leading: Icon(Icons.search),
                  title: Text('No recovery scan results'),
                ),
              for (final result in state.results)
                ListTile(
                  leading: const Icon(Icons.swap_horiz),
                  title: Text(result.swapId),
                  subtitle: Text(result.reason ?? result.status),
                  trailing: result.claimTxid == null
                      ? null
                      : const Icon(Icons.check_circle),
                ),
            ],
          ),
        );
      },
    );
  }
}
