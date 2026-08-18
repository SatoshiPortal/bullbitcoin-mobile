import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_router.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class ImportMethodWidget extends StatelessWidget {
  const ImportMethodWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Gap(12),
        BullButton.secondary(
          label: context.loc.importWatchOnlyScanQR,
          onPressed: () =>
              context.replaceNamed(ImportWatchOnlyWalletRoutes.scan.name),
          iconData: Icons.qr_code_scanner,
        ),
        const Gap(12),
      ],
    );
  }
}
