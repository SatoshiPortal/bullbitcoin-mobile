import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/settings/ui/widgets/address_list_bottom_sheet.dart';
import 'package:bb_mobile/features/settings/ui/widgets/wallet_deletion_confirmation_alert_dialog.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
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
    Wallet? wallet;
    try {
      wallet = context.read<WalletBloc>().state.wallets.firstWhere(
        (w) => w.id == walletId,
      );
    } catch (e) {
      log.severe('Wallet with ID $walletId not found to show details');
    }
    final isDeletingWallet = context.select(
      (WalletBloc bloc) => bloc.state.isDeletingWallet,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Wallet Details'),
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
                                  walletId: wallet!.id,
                                ),
                      ),
              icon: const Icon(CupertinoIcons.delete),
            ),
        ],
      ),
      body: SafeArea(
        child:
            wallet == null
                ? const Center(child: Text('Wallet not found'))
                : ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  children: [
                    _InfoField(
                      label: 'Wallet fingerprint',
                      value: wallet.masterFingerprint,
                    ),
                    const SizedBox(height: 18),
                    _CopyField(label: 'Pubkey', value: wallet.xpub),
                    const SizedBox(height: 18),
                    _CopyField(
                      label: 'Descriptor',
                      value: wallet.externalPublicDescriptor,
                    ),
                    const SizedBox(height: 18),
                    _InfoField(
                      label: 'Address type',
                      value: wallet.getWalletTypeString(),
                    ),
                    const SizedBox(height: 18),
                    _InfoField(
                      label: 'Derivation Path',
                      value: wallet.derivationPath,
                    ),
                    const Gap(18),
                    ListTile(
                      // Remove the default border and padding
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      tileColor: Colors.transparent,
                      contentPadding: EdgeInsets.zero,
                      title: BBText(
                        'View addresses',
                        style: context.font.bodyLarge?.copyWith(
                          color: context.colour.outline,
                        ),
                      ),
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          builder: (bottomSheetContext) {
                            return const AddressListBottomSheet();
                          },
                        );
                      },
                      trailing: const Icon(Icons.arrow_drop_down),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          label,
          style: context.font.bodyLarge?.copyWith(
            color: context.colour.surfaceContainer,
          ),
        ),
        const Gap(4),
        BBText(
          value,
          style: context.font.bodyMedium?.copyWith(
            color: context.colour.outline,
          ),
        ),
      ],
    );
  }
}

class _CopyField extends StatelessWidget {
  final String label;
  final String value;
  const _CopyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          label,
          style: context.font.bodyLarge?.copyWith(
            color: context.colour.surfaceContainer,
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
                color: context.colour.outline,
              ),
            ),

            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                log.info('Copied $label to clipboard');
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BBText(
                    'Copy',
                    style: context.font.bodyMedium?.copyWith(
                      color: context.colour.primary,
                      fontSize: 14,
                    ),
                  ),
                  const Gap(4),
                  Icon(Icons.copy, size: 16, color: context.colour.primary),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
