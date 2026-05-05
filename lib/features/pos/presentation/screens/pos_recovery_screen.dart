import 'package:bb_mobile/features/pos/presentation/bloc/pos_cubit.dart';
import 'package:bb_mobile/features/pos/presentation/bloc/pos_recovery_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_pos/nostr_pos.dart' as nostr;

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
                  subtitle: Text(_recoverySubtitle(result)),
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

  String _recoverySubtitle(nostr.ControllerRecoveryResult result) {
    final reason = result.reason;
    if (reason != null && reason.isNotEmpty) return reason;
    final providerStatus = result.providerStatus;
    return switch (result.statusKind) {
      nostr.RecoveryStatus.waiting =>
        providerStatus == null
            ? 'Waiting for a claimable Liquid lockup transaction.'
            : 'Waiting for claimable Liquid lockup ($providerStatus).',
      nostr.RecoveryStatus.alreadyClaimed => 'Already claimed by the terminal.',
      nostr.RecoveryStatus.broadcast =>
        result.claimTxid == null
            ? 'Claim transaction broadcast.'
            : 'Claim transaction broadcast: ${result.claimTxid}',
      nostr.RecoveryStatus.expired => 'Recovery window expired.',
      nostr.RecoveryStatus.failed || nostr.RecoveryStatus.unknown =>
        providerStatus == null
            ? result.defaultDebugMessage
            : '${result.defaultDebugMessage} ($providerStatus)',
    };
  }
}
