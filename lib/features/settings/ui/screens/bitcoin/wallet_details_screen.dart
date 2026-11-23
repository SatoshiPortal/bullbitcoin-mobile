import 'package:address_view/address_view.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/settings/ui/widgets/wallet_deletion_confirmation_sheet.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullText,
        BullButton,
        BullCopyField,
        BullIcon,
        BullIcons,
        Gap,
        BullTypographyX;
import 'package:bb_mobile/features/settings/ui/widgets/wallet_discovery_button.dart';

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
        title: Text(
          wallet?.displayLabel(context) ??
              context.loc.walletDetailsUnnamedWalletFallback,
        ),
        actions: [
          if (wallet != null && wallet.isDefault == false)
            IconButton(
              tooltip: context.loc.walletDeletionConfirmationTitle,
              onPressed: isDeletingWallet
                  ? null
                  : () => WalletDeletionConfirmationSheet.show(
                      context,
                      onConfirm: () => context.read<WalletBloc>().add(
                        WalletDeleted(wallet.id),
                      ),
                    ),
              icon: const BullIcon(BullIcons.deleteOutline),
            ),
        ],
      ),
      body: SafeArea(
        child: isDeletingWallet
            ? Center(
                child: Column(
                  mainAxisAlignment: .center,
                  children: [
                    const CircularProgressIndicator(),
                    const Gap(16),
                    BullText(
                      context.loc.walletDetailsDeletingMessage,
                      style: context.bullType.body.copyWith(
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
                  ),
                  const SizedBox(height: 18),
                  _CopyField(
                    label: context.loc.walletDetailsDescriptorLabel,
                    value: wallet.externalPublicDescriptor,
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
                    value:
                        wallet.signerDevice?.displayName ??
                        context.loc.walletDetailsSignerDeviceNotSupported,
                  ),
                  const Gap(32),
                  WalletDiscoveryButton(walletId: walletId),
                  const Gap(16),
                  BullButton.secondary(
                    label: context.loc.addressViewAddressesTitle,
                    onPressed: () => AddressViewNavigation.open(
                      context,
                      walletId: wallet.id,
                    ),
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
        BullText(
          label,
          style: context.bullType.body
              .copyWith(fontWeight: FontWeight.w500)
              .copyWith(color: context.appColors.textMuted),
        ),
        const Gap(4),
        BullText(
          value,
          style: context.bullType.body.copyWith(
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
  const _CopyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        BullText(
          label,
          style: context.bullType.body
              .copyWith(fontWeight: FontWeight.w500)
              .copyWith(color: context.appColors.textMuted),
        ),
        const Gap(4),
        BullCopyField(
          text: value,
          copiedMessage: context.loc.copiedToClipboard,
          copyLabel: context.loc.copyDialogButton,
        ),
      ],
    );
  }
}
