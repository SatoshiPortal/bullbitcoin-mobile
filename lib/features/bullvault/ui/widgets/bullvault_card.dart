import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bull_ui/bull_ui.dart' show BullBorderedTile, Gap;
import 'package:flutter/material.dart';

final class BullVaultCard extends StatelessWidget {
  final BullVaultRecord record;
  final VoidCallback? onTap;
  const BullVaultCard({super.key, required this.record, this.onTap});

  @override
  Widget build(BuildContext context) {
    final policy = record.recoveryPackage.policy;
    final id = record.walletId;
    final shortId = id.length <= 8 ? id : id.substring(0, 8);
    final activations = [
      ?policy.recoveryActivationTimestamp,
      ?policy.coldActivationTimestamp,
      ?policy.inheritanceActivationTimestamp,
      ?policy.lastResortActivationTimestamp,
    ]..sort();
    final firstRecovery = activations.firstOrNull;
    String date(DateTime? value) => value == null
        ? context.loc.walletDetailsUnavailableLabel
        : MaterialLocalizations.of(context).formatFullDate(value.toLocal());
    return Semantics(
      button: onTap != null,
      child: BullBorderedTile(
        onTap: onTap,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.loc.bullVaultWalletLabel,
                    style: context.font.titleLarge,
                  ),
                ),
                if (onTap != null) const Icon(Icons.chevron_right),
              ],
            ),
            const Gap(16),
            Text(context.loc.bullVaultIdentifier(shortId)),
            const Gap(8),
            Text(context.loc.bullVaultCreatedDate(date(policy.createdAt))),
            const Gap(8),
            Text(
              context.loc.bullVaultExpiryDate(
                date(
                  firstRecovery == null
                      ? null
                      : DateTime.fromMillisecondsSinceEpoch(
                          firstRecovery * 1000,
                          isUtc: true,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
