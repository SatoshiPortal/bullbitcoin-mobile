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
    final address = snapshot.account == config.id
        ? snapshot.reserveAddress
        : null;
    final reserve = snapshot.confirmedReserve;
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
              if (snapshot.stale) BullInfoBar(message: l10n.stale),
              if (address != null && address.trim().isNotEmpty)
                Column(
                  key: const ValueKey('ark-fee-reserve'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BullText(l10n.feeReserveTitle, role: BullTextRole.subtitle),
                    const Gap(BullSpacing.sm),
                    BullText(
                      reserve == null
                          ? l10n.unknown
                          : l10n.feeReserveAmount(reserve.value.toString()),
                      role: BullTextRole.body,
                    ),
                    const Gap(BullSpacing.sm),
                    BullInfoBar(message: l10n.feeReserveHelp),
                    const Gap(BullSpacing.md),
                    Center(
                      child: BullQrCode(
                        data: address,
                        size: 200,
                        semanticsLabel: l10n.feeReserveTitle,
                      ),
                    ),
                    const Gap(BullSpacing.md),
                    BullCopyField(
                      text: address,
                      clipboardText: address,
                      copiedMessage: l10n.copied,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(BullSpacing.lg),
                  ],
                ),
              BullInfoBar(message: l10n.privacy),
              const Gap(BullSpacing.md),
              ArkConnectionDetails(config: config),
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
