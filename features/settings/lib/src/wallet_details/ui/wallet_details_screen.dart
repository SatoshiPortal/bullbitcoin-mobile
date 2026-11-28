import 'package:address_view/address_view.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullText,
        BullButton,
        BullCopyField,
        BullFadingLinearProgress,
        BullIcon,
        BullIcons,
        Gap,
        BullTypographyX;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

import '../../../generated/l10n/settings_localizations.dart';
import '../domain/wallet_details.dart';
import '../presentation/wallet_details_cubit.dart';
import '../presentation/wallet_details_failure_l10n.dart';
import 'wallet_deletion_confirmation_sheet.dart';
import 'wallet_deletion_failed_sheet.dart';
import 'wallet_discovery_button.dart';

class WalletDetailsScreen extends StatelessWidget {
  const WalletDetailsScreen({super.key, required this.onDeleted});

  /// Leaves the deleted wallet's screens once its deletion is committed.
  final void Function(BuildContext context) onDeleted;

  @override
  Widget build(BuildContext context) {
    final loc = SettingsLocalizations.of(context);
    return BlocConsumer<WalletDetailsCubit, WalletDetailsState>(
      listenWhen: (previous, current) =>
          current is WalletDetailsDeleted ||
          (current is WalletDetailsLoaded &&
              current.deletionFailure != null &&
              (previous is! WalletDetailsLoaded ||
                  previous.deletionFailure == null)),
      listener: (context, state) {
        switch (state) {
          case WalletDetailsDeleted():
            onDeleted(context);
          case WalletDetailsLoaded(deletionFailure: final failure?):
            WalletDeletionFailedSheet.show(context, failure: failure);
          case _:
            break;
        }
      },
      builder: (context, state) {
        final details = switch (state) {
          WalletDetailsLoaded(:final details) => details,
          _ => null,
        };
        final isDeleting =
            state is WalletDetailsDeleted ||
            (state is WalletDetailsLoaded && state.isDeleting);
        return Scaffold(
          appBar: AppBar(
            title: Text(
              details == null
                  ? loc.walletDetailsUnnamedWalletFallback
                  : _displayLabel(loc, details),
            ),
            actions: [
              if (details != null && !details.isDefault)
                IconButton(
                  tooltip: loc.walletDeletionConfirmationTitle,
                  onPressed: isDeleting
                      ? null
                      : () => WalletDeletionConfirmationSheet.show(
                          context,
                          onConfirm: () =>
                              context.read<WalletDetailsCubit>().delete(),
                        ),
                  icon: const BullIcon(BullIcons.deleteOutline),
                ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(3),
              child: BullFadingLinearProgress(
                height: 3,
                trigger: isDeleting || state is WalletDetailsLoading,
                backgroundColor: context.appColors.surface,
                foregroundColor: context.appColors.primary,
              ),
            ),
          ),
          body: SafeArea(
            child: isDeleting
                ? Center(
                    child: BullText(
                      loc.walletDetailsDeletingMessage,
                      style: context.bullType.body.copyWith(
                        color: context.appColors.textMuted,
                      ),
                    ),
                  )
                : switch (state) {
                    WalletDetailsLoading() => const SizedBox.shrink(),
                    WalletDetailsMissing(:final failure) => Center(
                      child: Text(failure.toTranslated(context)),
                    ),
                    _ when details != null => _DetailsList(details: details),
                    _ => const SizedBox.shrink(),
                  },
          ),
        );
      },
    );
  }

  static String _displayLabel(SettingsLocalizations loc, WalletDetails wallet) {
    if (!wallet.isDefault) {
      return wallet.label ?? wallet.id.replaceFirst(RegExp(r':regtest$'), '');
    }
    return switch (wallet.network) {
      BitcoinNetwork() => loc.globalDefaultBitcoinWalletLabel,
      LiquidNetwork() => loc.globalDefaultLiquidWalletLabel,
    };
  }
}

class _DetailsList extends StatelessWidget {
  final WalletDetails details;

  const _DetailsList({required this.details});

  @override
  Widget build(BuildContext context) {
    final loc = SettingsLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _InfoField(
          label: loc.walletDetailsWalletFingerprintLabel,
          value: details.masterFingerprint,
        ),
        const SizedBox(height: 18),
        _CopyField(label: loc.walletDetailsPubkeyLabel, value: details.xpub),
        const SizedBox(height: 18),
        _CopyField(
          label: loc.walletDetailsDescriptorLabel,
          value: details.externalDescriptor,
        ),
        const SizedBox(height: 18),
        _InfoField(
          label: loc.walletDetailsAddressTypeLabel,
          value: details.addressType,
        ),
        const SizedBox(height: 18),
        _InfoField(
          label: loc.walletDetailsNetworkLabel,
          value: details.networkName,
        ),
        const SizedBox(height: 18),
        _InfoField(
          label: loc.walletDetailsDerivationPathLabel,
          value: details.derivationPath,
        ),
        const SizedBox(height: 18),
        _InfoField(
          label: loc.walletDetailsSignerLabel,
          value: details.signer.displayName,
        ),
        const SizedBox(height: 18),
        _InfoField(
          label: loc.walletDetailsSignerDeviceLabel,
          value:
              details.signerDevice?.displayName ??
              loc.walletDetailsSignerDeviceNotSupported,
        ),
        const Gap(32),
        WalletDiscoveryButton(walletId: details.id),
        const Gap(16),
        BullButton.secondary(
          label: loc.addressViewAddressesTitle,
          onPressed: () =>
              AddressViewNavigation.open(context, walletId: details.id),
        ),
      ],
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
          copiedMessage: SettingsLocalizations.of(context).copiedToClipboard,
          copyLabel: SettingsLocalizations.of(context).copyDialogButton,
        ),
      ],
    );
  }
}
