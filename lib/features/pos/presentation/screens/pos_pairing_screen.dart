import 'package:bb_mobile/core/widgets/qr_scanner_widget.dart';
import 'package:bb_mobile/features/pos/presentation/bloc/pos_cubit.dart';
import 'package:bb_mobile/features/pos/presentation/widgets/pos_pairing_code_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PosPairingScreen extends StatefulWidget {
  const PosPairingScreen({super.key});

  @override
  State<PosPairingScreen> createState() => _PosPairingScreenState();
}

class _PosPairingScreenState extends State<PosPairingScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosCubit, PosState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Pair Terminal')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (state.isLoading) const LinearProgressIndicator(),
              if (state.error != null)
                ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(state.error!),
                ),
              PosPairingCodeInput(controller: _code),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.link),
                      label: const Text('Pair'),
                      onPressed: state.identity == null || state.isLoading
                          ? null
                          : () => context.read<PosCubit>().pair(_code.text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Scan QR',
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () => _scan(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final terminal in state.terminals)
                ListTile(
                  leading: const Icon(Icons.devices_other),
                  title: Text(_shortKey(terminal.terminalPubkey)),
                  subtitle: Text(terminal.isRevoked ? 'Revoked' : 'Authorized'),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _scan(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Scan Pairing QR')),
          body: QrScannerWidget(
            onScanned: (value) {
              _code.text = value.trim();
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }

  String _shortKey(String key) {
    if (key.length <= 16) return key;
    return '${key.substring(0, 8)}...${key.substring(key.length - 8)}';
  }
}
