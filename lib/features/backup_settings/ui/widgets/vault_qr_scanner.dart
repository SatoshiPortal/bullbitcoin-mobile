import 'package:bb_mobile/core/widgets/qr_scanner_widget.dart';
import 'package:flutter/material.dart';

/// Scans one code and returns it, for the recovery screens that take a
/// descriptor or a cosigner's account key.
///
/// The feature's scanning screens were identical apart from their title, so
/// they are one screen here. It stays inside `backup_settings` because
/// `QrScannerWidget` is the only shared piece: every feature that scans owns
/// its own framing screen.
Future<String?> pushVaultQrScanner(
  BuildContext context, {
  required String title,
}) => Navigator.of(context).push<String>(
  MaterialPageRoute(builder: (_) => _VaultQrScannerScreen(title: title)),
);

final class _VaultQrScannerScreen extends StatefulWidget {
  final String title;

  const _VaultQrScannerScreen({required this.title});

  @override
  State<_VaultQrScannerScreen> createState() => _VaultQrScannerScreenState();
}

final class _VaultQrScannerScreenState extends State<_VaultQrScannerScreen> {
  bool _delivered = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: QrScannerWidget(
      onScanned: (value) {
        if (_delivered) return;
        _delivered = true;
        Navigator.of(context).pop(value);
      },
    ),
  );
}
