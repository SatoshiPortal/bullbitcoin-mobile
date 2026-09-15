import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/inspect_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_key_summary.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:flutter/material.dart';

/// Reuses the generic policy renderer, with verified BullVault key annotations.
class BullVaultPolicyPanel extends StatelessWidget {
  final BullVaultInspection inspection;
  const BullVaultPolicyPanel({super.key, required this.inspection});

  WalletSigner? _signer(BitcoinPolicyKey key) {
    final matches = inspection.wallet.signers
        .where((signer) => signer.descriptorKeys.any(key.matches))
        .toList();
    // A fingerprint is not unique. Ambiguous references must not claim access.
    return matches.length == 1 ? matches.single : null;
  }

  @override
  Widget build(BuildContext context) => WalletPolicyView(
    wallet: inspection.wallet,
    signerName: (key) {
      final signer = _signer(key);
      return signer == null
          ? context.loc.walletDetailsUnavailableLabel
          : bullVaultSignerName(context, inspection, signer, policyKey: key);
    },
    signerBuilder: (context, key) {
      final signer = _signer(key);
      return signer == null
          ? Text(context.loc.walletDetailsUnavailableLabel)
          : BullVaultKeySummary(
              inspection: inspection,
              signer: signer,
              policyKey: key,
            );
    },
  );
}
