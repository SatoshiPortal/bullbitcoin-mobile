import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/settings/ui/widgets/wallet_detail_fields.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

class WalletSignerDetails extends StatelessWidget {
  final List<WalletSigner> signers;

  const WalletSignerDetails({super.key, required this.signers});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        BBText(
          context.loc.walletDetailsSignersLabel,
          style: context.font.titleLarge,
        ),
        const Gap(18),
        for (final (index, signer) in signers.indexed) ...[
          _SignerDetails(index: index, signer: signer),
          if (index != signers.length - 1) const Gap(28),
        ],
      ],
    );
  }
}

class _SignerDetails extends StatelessWidget {
  final int index;
  final WalletSigner signer;

  const _SignerDetails({required this.index, required this.signer});

  @override
  Widget build(BuildContext context) {
    final fingerprint = signer.displayFingerprint;
    final label = fingerprint.isEmpty
        ? context.loc.walletSignerLabel(index + 1)
        : context.loc.walletSignerLabelWithFingerprint(index + 1, fingerprint);
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        BBText(
          label,
          style: context.font.titleMedium?.copyWith(fontWeight: .w600),
        ),
        const Gap(12),
        WalletDetailInfoField(
          label: context.loc.walletDetailsSignerLabel,
          value: _signerDescription(context, signer),
        ),
        for (final (keyIndex, key) in signer.descriptorKeys.indexed) ...[
          if (signer.descriptorKeys.length > 1) ...[
            const Gap(18),
            BBText(
              context.loc.walletDetailsKeyLabel(keyIndex + 1),
              style: context.font.bodyLarge?.copyWith(fontWeight: .w500),
            ),
          ],
          if (key.derivationPath case final path? when path.isNotEmpty) ...[
            const Gap(18),
            WalletDetailInfoField(
              label: context.loc.walletDetailsDerivationPathLabel,
              value: path,
            ),
          ],
          if (key.xpub.isNotEmpty) ...[
            const Gap(18),
            WalletDetailCopyField(
              label: context.loc.importWatchOnlyExtendedPublicKey,
              value: key.xpub,
              copyLabel: context.loc.walletDetailsCopyButton,
            ),
          ],
        ],
      ],
    );
  }
}

String _signerDescription(BuildContext context, WalletSigner signer) {
  if (signer.signer == SignerEntity.local) {
    return context.loc.importWatchOnlyBullMobileDevice;
  }
  if (signer.signerDevice case final device?) return device.displayName;
  if (signer.signer == SignerEntity.remote) {
    return context.loc.walletDetailsExternalSignerLabel;
  }
  return context.loc.walletDetailsUnassignedSignerLabel;
}
