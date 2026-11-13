import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/qr_scanner_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum BullVaultScannerPurpose { publicAccountKey, descriptor }

final class BullVaultScannerScreen extends StatelessWidget {
  final BullVaultScannerPurpose purpose;

  const BullVaultScannerScreen({super.key, required this.purpose});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(switch (purpose) {
        BullVaultScannerPurpose.publicAccountKey =>
          context.loc.bullVaultScanPublicKey,
        BullVaultScannerPurpose.descriptor =>
          context.loc.bullVaultScanDescriptor,
      }),
    ),
    body: QrScannerWidget(onScanned: (value) => context.pop(value)),
  );
}
