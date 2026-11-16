import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';

import '../presentation/ark_l10n.dart';

class ArkConnectionDetails extends StatelessWidget {
  final ArkAccountConfig config;

  const ArkConnectionDetails({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    return BullDetailsTable(
      items: [
        BullDetailsTableItem(
          label: l10n.arkServer,
          displayValue: config.arkUrl.toString(),
        ),
        BullDetailsTableItem(
          label: l10n.primaryChainSource,
          displayValue: config.primaryEsploraUrl.toString(),
        ),
        if (config.fallbackEsploraUrl case final fallback?)
          BullDetailsTableItem(
            label: l10n.fallbackChainSource,
            displayValue: fallback.toString(),
          ),
        BullDetailsTableItem(
          label: l10n.renewalThreshold,
          displayValue: config.renewalThresholdBlocks.toString(),
        ),
      ],
    );
  }
}
