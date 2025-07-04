import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/features/settings/presentation/bloc/wallet_details_cubit.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class WalletDetailsScreen extends StatelessWidget {
  final String walletId;

  const WalletDetailsScreen({super.key, required this.walletId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => WalletDetailsCubit(walletId: walletId),
      child: _WalletDetailsView(walletId: walletId),
    );
  }
}

class _WalletDetailsView extends StatelessWidget {
  final String walletId;

  const _WalletDetailsView({required this.walletId});

  @override
  Widget build(BuildContext context) {
    final isDefault =
        context
            .read<WalletBloc>()
            .state
            .wallets
            .firstWhere((w) => w.id == walletId)
            .isDefault;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Wallet Details',
          onBack: () => context.pop(),
        ),
        actions: [
          if (isDefault)
            const SizedBox.shrink()
          else
            BlocBuilder<WalletDetailsCubit, WalletDetailsState>(
              builder: (context, state) {
                final isDeleting =
                    state.deleteStatus == WalletDeleteStatus.loading;
                return IconButton(
                  onPressed:
                      isDeleting
                          ? null
                          : () => _showDeleteConfirmationDialog(context),
                  icon:
                      isDeleting
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(CupertinoIcons.delete),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<WalletBloc, WalletState>(
          builder: (context, walletState) {
            final wallet =
                walletState.wallets.where((w) => w.id == walletId).firstOrNull;
            if (wallet == null) {
              return const Center(child: Text('Wallet not found'));
            }
            return BlocConsumer<WalletDetailsCubit, WalletDetailsState>(
              listener: (context, state) {
                if (state.deleteStatus == WalletDeleteStatus.success) {
                  context.goNamed(WalletRoute.walletHome.name);
                } else if (state.deleteStatus == WalletDeleteStatus.error) {
                  _showErrorDialog(context, state.deleteError);
                }
              },
              builder: (context, state) {
                final derivationPath =
                    "m / ${wallet.scriptType.purpose}' / 0' / 0'";
                return ListView(
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
                    _InfoField(label: 'Derivation Path', value: derivationPath),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    final wallet =
        context
            .read<WalletBloc>()
            .state
            .wallets
            .where((w) => w.id == walletId)
            .firstOrNull;

    if (wallet == null) return;

    final walletName = wallet.getLabel() ?? 'Unnamed Wallet';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder:
          (bottomSheetContext) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 5,
                      child: BBText(
                        'Are you sure you want to delete "$walletName"? ',
                        style: context.font.headlineMedium?.copyWith(
                          color: context.colour.secondary,
                        ),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: IconButton(
                        onPressed: () => Navigator.of(bottomSheetContext).pop(),
                        icon: const Icon(Icons.close),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
                const Gap(12),
                // Content
                BBText(
                  'This action cannot be undone. Make sure you have backed up your wallet.',
                  style: context.font.bodyMedium?.copyWith(
                    color: context.colour.outline,
                  ),
                ),
                const Gap(24),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: BBButton.big(
                        label: 'Cancel',
                        onPressed: () => Navigator.of(bottomSheetContext).pop(),
                        bgColor: Colors.transparent,
                        outlined: true,
                        textColor: context.colour.secondary,
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: BBButton.big(
                        label: 'Delete',
                        onPressed: () {
                          Navigator.of(bottomSheetContext).pop();
                          context.read<WalletDetailsCubit>().deleteWallet();
                        },
                        bgColor: context.colour.secondary,
                        textColor: context.colour.onPrimary,
                      ),
                    ),
                  ],
                ),
                // Add bottom padding for safe area
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16),
              ],
            ),
          ),
    );
  }

  void _showErrorDialog(BuildContext context, String? errorMessage) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Delete Failed'),
            content: BBText(
              errorMessage ??
                  'An unknown error occurred while deleting the wallet.',
              style: context.font.bodyMedium?.copyWith(
                color: context.colour.error,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
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
