import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';

import '../presentation/ark_l10n.dart';
import 'ark_connection_details.dart';

class ArkInformationScreen extends StatelessWidget {
  final ArkSnapshot snapshot;
  final ArkAccountConfig config;
  const ArkInformationScreen({
    super.key,
    required this.snapshot,
    required this.config,
  });
  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final info = snapshot.serverInfo;
    return BullScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BullSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BullTopBar(
                title: l10n.info,
                onBack: () => Navigator.pop(context),
              ),
              BullInfoBar(message: l10n.privacy),
              const Gap(BullSpacing.md),
              ArkConnectionDetails(config: config),
              if (snapshot.stale) BullInfoBar(message: l10n.stale),
              BullDetailsTable(
                items: [
                  BullDetailsTableItem(
                    label: l10n.publicServerKey,
                    displayValue: info?.publicKey ?? l10n.unknown,
                    copyValue: info?.publicKey,
                    copiedMessage: l10n.copied,
                  ),
                  BullDetailsTableItem(
                    label: l10n.minimumBoard,
                    displayValue:
                        info?.minimumBoard?.toString() ?? l10n.unknown,
                  ),
                  BullDetailsTableItem(
                    label: l10n.maximumVtxo,
                    displayValue: info?.maximumVtxo?.toString() ?? l10n.unknown,
                  ),
                  BullDetailsTableItem(
                    label: l10n.boardConfirmations,
                    displayValue:
                        info?.boardConfirmations?.toString() ?? l10n.unknown,
                  ),
                  BullDetailsTableItem(
                    label: l10n.roundInterval,
                    displayValue:
                        info?.roundIntervalSeconds?.toString() ?? l10n.unknown,
                  ),
                  BullDetailsTableItem(
                    label: l10n.vtxoLifetime,
                    displayValue:
                        info?.vtxoLifetimeBlocks?.toString() ?? l10n.unknown,
                  ),
                ],
              ),
              BullInfoBar(message: l10n.backgroundNotice),
            ],
          ),
        ),
      ),
    );
  }
}
