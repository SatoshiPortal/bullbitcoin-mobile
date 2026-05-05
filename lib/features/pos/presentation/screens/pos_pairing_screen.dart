import 'package:bb_mobile/core/widgets/qr_scanner_widget.dart';
import 'package:bb_mobile/features/pos/presentation/bloc/pos_cubit.dart';
import 'package:bb_mobile/features/pos/presentation/widgets/pos_pairing_code_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Paste',
                    icon: const Icon(Icons.content_paste),
                    onPressed: () => _paste(context),
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
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (context) => const _PairingQrScannerScreen(),
      ),
    );
    if (!mounted || code == null) return;
    _code.text = code;
  }

  Future<void> _paste(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final code = _extractPairingCode(data?.text ?? '');
    if (!mounted) return;
    if (code == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clipboard does not contain a pairing code'),
        ),
      );
      return;
    }
    _code.text = code;
  }

  String _shortKey(String key) {
    if (key.length <= 16) return key;
    return '${key.substring(0, 8)}...${key.substring(key.length - 8)}';
  }
}

String? _extractPairingCode(String value) {
  final normalized = value.trim().toUpperCase();
  final match = RegExp(
    r'[0-9A-HJKMNP-TV-Z]{4}-[0-9A-HJKMNP-TV-Z]{4}',
  ).firstMatch(normalized);
  return match?.group(0);
}

class _PairingQrScannerScreen extends StatefulWidget {
  const _PairingQrScannerScreen();

  @override
  State<_PairingQrScannerScreen> createState() =>
      _PairingQrScannerScreenState();
}

class _PairingQrScannerScreenState extends State<_PairingQrScannerScreen> {
  bool _handled = false;
  String? _lastScan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          QrScannerWidget(
            scanDelay: const Duration(milliseconds: 100),
            onScanned: (value) {
              if (_handled) return;
              final code = _extractPairingCode(value);
              if (code == null) {
                setState(() => _lastScan = value);
                return;
              }
              _handled = true;
              Navigator.of(context).pop(code);
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _lastScan == null
                      ? 'Scan the terminal pairing QR code'
                      : 'Scanned something else: $_lastScan',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          Positioned(
            top: 48,
            right: 16,
            child: IconButton.filled(
              tooltip: 'Close',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
