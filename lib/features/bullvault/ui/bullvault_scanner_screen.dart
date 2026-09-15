import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/qr_scanner_widget.dart';
import 'package:flutter/material.dart';

enum BullVaultScannerPurpose { publicAccountKey, descriptor }

final class BullVaultScannerScreen extends StatefulWidget {
  final BullVaultScannerPurpose purpose;

  const BullVaultScannerScreen({super.key, required this.purpose});

  @override
  State<BullVaultScannerScreen> createState() => _BullVaultScannerScreenState();
}

class _BullVaultScannerScreenState extends State<BullVaultScannerScreen> {
  bool _delivered = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(switch (widget.purpose) {
        BullVaultScannerPurpose.publicAccountKey =>
          context.loc.bullVaultScanPublicKey,
        BullVaultScannerPurpose.descriptor =>
          context.loc.bullVaultScanDescriptor,
      }),
    ),
    body: QrScannerWidget(
      onScanned: (value) {
        if (_delivered) return;
        _delivered = true;
        Navigator.of(context).pop(value);
      },
    ),
  );
}
