import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_signer_key.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/inspect_bullvault_usecase.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

String bullVaultSignerName(
  BuildContext context,
  BullVaultInspection inspection,
  WalletSigner signer, {
  BitcoinPolicyKey? policyKey,
}) {
  final policy = inspection.record.recoveryPackage.policy;
  final definitions = [
    policy.everydayKey,
    ?policy.delayedMobileRecoveryKey,
    policy.coldKey,
    ?policy.secondColdKey,
    ?policy.inheritanceKey,
  ];
  final keys = signer.descriptorKeys.where(
    (key) => policyKey == null || policyKey.matches(key),
  );
  final roles = definitions
      .where(
        (definition) => keys.any(
          (key) =>
              Bip32Derivation.getBip32Xpub(key.xpub).toBase58() ==
              Bip32Derivation.getBip32Xpub(
                definition.accountKey.xpub,
              ).toBase58(),
        ),
      )
      .map((key) => key.role)
      .toSet();
  final name =
      roles.isNotEmpty &&
          roles.every(
            (role) =>
                role == BullVaultSignerRole.everyday ||
                role == BullVaultSignerRole.delayedMobileRecovery,
          )
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
  return '$name · ${signer.displayFingerprint}';
}

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
    final keys = signer.descriptorKeys.where(
      (key) => policyKey == null || policyKey!.matches(key),
    );
    final statuses = keys.map((key) => inspection.keyAccess[key.id]).toSet();
    final access = statuses.length == 1
        ? statuses.single
        : BullVaultKeyAccess.unavailable;
    final label = switch (access) {
      BullVaultKeyAccess.available => context.loc.bullVaultKeyOnDevice,
      BullVaultKeyAccess.passphraseRequired =>
        context.loc.bullVaultKeyPassphraseRequired,
      BullVaultKeyAccess.external => context.loc.bullVaultKeyExternal,
      _ => context.loc.walletDetailsUnavailableLabel,
    };
    // The shared policy card supplies its foreground, including its dark first
    // stage. Don't impose the screen's black body text inside that card.
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
        Text(label, style: context.font.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}
