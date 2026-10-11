import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_inspection.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_key_summary.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BullVaultPolicyPanel extends StatelessWidget {
  final BullVaultInspection inspection;
  const BullVaultPolicyPanel({super.key, required this.inspection});
  @override
  Widget build(BuildContext context) => WalletPolicyView(
    walletId: inspection.wallet.id,
    builder: (context, policy) =>
        BullVaultPolicyDetails(inspection: inspection, policy: policy),
  );
}

class BullVaultPolicyDetails extends StatelessWidget {
  final BullVaultInspection inspection;
  final BitcoinWalletPolicy policy;
  const BullVaultPolicyDetails({
    super.key,
    required this.inspection,
    required this.policy,
  });

  @override
  Widget build(BuildContext context) => WalletPolicyDetailsContent(
    wallet: inspection.wallet,
    policy: policy,
    conditionBuilder: _condition,
    alternativePathsFooter: Text(
      context.loc.walletPolicyEarlierOptions,
      style: context.font.bodySmall?.copyWith(
        color: context.appColors.textMuted,
      ),
    ),
  );

  Widget? _condition(BuildContext context, BitcoinPolicyNode node) {
    if (node is BitcoinSignaturePolicyNode) {
      final signer = inspection.signerForKey(node.key);
      return signer == null
          ? Text(context.loc.walletDetailsUnavailableLabel)
          : BullVaultKeySummary(
              inspection: inspection,
              signer: signer,
              policyKey: node.key,
            );
    }
    if (node is BitcoinAbsoluteTimelockPolicyNode &&
        node.type == BitcoinAbsoluteTimelockType.timestamp) {
      final date = DateTime.fromMillisecondsSinceEpoch(
        node.value * 1000,
        isUtc: true,
      );
      final format = DateFormat.yMMMd(
        Localizations.localeOf(context).toLanguageTag(),
      );
      final clock = date.second == 0 ? format.add_Hm() : format.add_Hms();
      return Text(
        context.loc.walletDetailsAbsoluteTimeCondition(
          '${clock.format(date)} ${date.timeZoneName}',
        ),
      );
    }
    return null;
  }
}
