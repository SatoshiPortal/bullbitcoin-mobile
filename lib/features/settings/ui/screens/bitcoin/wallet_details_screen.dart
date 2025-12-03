import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/settings/ui/widgets/wallet_deletion_confirmation_alert_dialog.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class WalletDetailsScreen extends StatelessWidget {
  const WalletDetailsScreen({super.key, required this.walletId});

  final String walletId;

  @override
  Widget build(BuildContext context) {
    final Wallet? wallet = context.select(
      (WalletBloc bloc) =>
          bloc.state.wallets.where((w) => w.id == walletId).firstOrNull,
    );
    final isDeletingWallet = context.select(
      (WalletBloc bloc) => bloc.state.isDeletingWallet,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.walletOptionsWalletDetailsTitle),
        actions: [
          if (wallet != null && wallet.isDefault == false)
            IconButton(
              onPressed:
                  isDeletingWallet
                      ? null
                      : () => showDialog(
                        context: context,
                        builder:
                            (dialogContext) =>
                                WalletDeletionConfirmationAlertDialog(
                                  walletId: wallet.id,
                                ),
                      ),
              icon: const Icon(CupertinoIcons.delete),
            ),
        ],
      ),
      body: SafeArea(
        child:
            isDeletingWallet
                ? Center(
                  child: Column(
                    mainAxisAlignment: .center,
                    children: [
                      const CircularProgressIndicator(),
                      const Gap(16),
                      BBText(
                        context.loc.walletDetailsDeletingMessage,
                        style: context.font.bodyMedium?.copyWith(
                          color: context.appColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                )
                : wallet == null
                ? Center(child: Text(context.loc.walletDeletionErrorWalletNotFound))
                : ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  children: [
                    _InfoField(
                      label: context.loc.walletDetailsWalletFingerprintLabel,
                      value: wallet.masterFingerprint,
                    ),
                    const SizedBox(height: 18),
                    _CopyField(
                      label: context.loc.walletDetailsPubkeyLabel,
                      value: wallet.xpub,
                      copyLabel: context.loc.walletDetailsCopyButton,
                    ),
                    const SizedBox(height: 18),
                    _CopyField(
                      label: context.loc.walletDetailsDescriptorLabel,
                      value: wallet.externalPublicDescriptor,
                      copyLabel: context.loc.walletDetailsCopyButton,
                    ),
                    const SizedBox(height: 18),
                    _InfoField(
                      label: context.loc.walletDetailsAddressTypeLabel,
                      value: wallet.addressType,
                    ),
                    const SizedBox(height: 18),
                    _InfoField(
                      label: context.loc.walletDetailsNetworkLabel,
                      value: wallet.networkString,
                    ),
                    const SizedBox(height: 18),
                    _InfoField(
                      label: context.loc.walletDetailsDerivationPathLabel,
                      value: wallet.derivationPath,
                    ),
                    const SizedBox(height: 18),
                    _InfoField(
                      label: context.loc.walletDetailsSignerLabel,
                      value: wallet.signer.displayName,
                    ),
                    const SizedBox(height: 18),
                    _InfoField(
                      label: context.loc.walletDetailsSignerDeviceLabel,
                      value: wallet.signerDevice?.displayName ??
                          context.loc.walletDetailsSignerDeviceNotSupported,
                    ),
                  ],
                ),
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  final String label;
  final String value;
  const _InfoField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        BBText(
          label,
          style: context.font.bodyLarge?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(4),
        BBText(
          value,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.onSurface,
          ),
        ),
      ],
    );
  }
}

class _CopyField extends StatelessWidget {
  final String label;
  final String value;
  final String copyLabel;
  const _CopyField({
    required this.label,
    required this.value,
    required this.copyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        BBText(
          label,
          style: context.font.bodyLarge?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            BBText(
              value,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurface,
              ),
            ),

            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                log.info('Copied $label to clipboard');
              },
              child: Row(
                mainAxisSize: .min,
                children: [
                  BBText(
                    copyLabel,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.primary,
                      fontSize: 14,
                    ),
                  ),
                  const Gap(4),
                  Icon(Icons.copy, size: 16, color: context.appColors.primary),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
