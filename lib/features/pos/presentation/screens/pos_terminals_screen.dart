import 'package:bb_mobile/features/pos/presentation/bloc/pos_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PosTerminalsScreen extends StatelessWidget {
  const PosTerminalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosCubit, PosState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('POS Terminals')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (state.isLoading) const LinearProgressIndicator(),
              if (state.error != null)
                ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(state.error!),
                ),
              if (state.terminals.isEmpty)
                const ListTile(
                  leading: Icon(Icons.devices_other),
                  title: Text('No paired terminals'),
                ),
              for (final terminal in state.terminals)
                ListTile(
                  leading: Icon(
                    terminal.isRevoked ? Icons.block : Icons.devices_other,
                  ),
                  title: Text(_shortKey(terminal.terminalPubkey)),
                  subtitle: Text(
                    terminal.isRevoked
                        ? 'Revoked'
                        : 'Branch ${terminal.terminalIndex}',
                  ),
                  trailing: terminal.isRevoked
                      ? null
                      : IconButton(
                          tooltip: 'Revoke',
                          icon: const Icon(Icons.block),
                          onPressed: () => context.read<PosCubit>().revoke(
                            terminal.terminalPubkey,
                          ),
                        ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _shortKey(String key) {
    if (key.length <= 16) return key;
    return '${key.substring(0, 8)}...${key.substring(key.length - 8)}';
  }
}
