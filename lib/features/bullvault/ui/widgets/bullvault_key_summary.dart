import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_inspection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_signer_key.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

String bullVaultSignerName(
  BuildContext context,
  BullVaultInspection inspection,
  WalletSigner signer, {
  BitcoinPolicyKey? policyKey,
}) {
  final roles = inspection.rolesForSigner(signer, policyKey: policyKey);
  final mobile =
      roles.isNotEmpty &&
      roles.every(
        (role) =>
            role == BullVaultSignerRole.everyday ||
            role == BullVaultSignerRole.delayedMobileRecovery,
      );
  final name = mobile
      ? context.loc.bullVaultKeyMobile
      : roles.length == 1
      ? switch (roles.single) {
          BullVaultSignerRole.cold => context.loc.bullVaultColdKey,
          BullVaultSignerRole.secondCold => context.loc.bullVaultColdKeyTwo,
          BullVaultSignerRole.inheritance =>
            context.loc.bullVaultKeyInheritance,
          _ => context.loc.bullVaultEverydayKey,
        }
      : context.loc.walletSignerLabel(
          inspection.wallet.signers.indexWhere(
                (value) => value.id == signer.id,
              ) +
              1,
        );
  return signer.displayFingerprint.isEmpty
      ? name
      : '$name · ${signer.displayFingerprint}';
}

String bullVaultKeyAccessLabel(
  BuildContext context,
  BullVaultKeyAccess access,
) => switch (access) {
  BullVaultKeyAccess.available => context.loc.bullVaultKeyOnDevice,
  BullVaultKeyAccess.unavailable => context.loc.walletDetailsUnavailableLabel,
  BullVaultKeyAccess.external => context.loc.bullVaultKeyExternal,
  BullVaultKeyAccess.passphraseRequired =>
    context.loc.bullVaultKeyPassphraseRequired,
};

class BullVaultKeySummary extends StatelessWidget {
  final BullVaultInspection inspection;
  final WalletSigner signer;
  final BitcoinPolicyKey? policyKey;
  const BullVaultKeySummary({
    super.key,
    required this.inspection,
    required this.signer,
    this.policyKey,
  });
  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          bullVaultSignerName(
            context,
            inspection,
            signer,
            policyKey: policyKey,
          ),
          style: context.font.titleSmall?.copyWith(color: color),
        ),
        const Gap(4),
        Text(
          bullVaultKeyAccessLabel(
            context,
            inspection.accessForSigner(signer, policyKey: policyKey),
          ),
          style: context.font.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
