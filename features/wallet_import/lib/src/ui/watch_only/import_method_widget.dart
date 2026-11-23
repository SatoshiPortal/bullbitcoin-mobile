import 'package:wallet_import/src/presentation/import_l10n.dart';
import 'package:wallet_import/src/import_navigation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, Gap;

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
              ImportNavigation.replaceWithWatchOnlyScanner(context),
          iconData: Icons.qr_code_scanner,
        ),
        const Gap(12),
      ],
    );
  }
}
