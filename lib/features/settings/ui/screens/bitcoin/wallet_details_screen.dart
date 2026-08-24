import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/dropdown/signer_device_dropdown.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/psbt_signing/public/psbt_signing_facade.dart';
import 'package:bb_mobile/features/settings/domain/wallet_registration.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/wallet_details_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_route.dart';
import 'package:bb_mobile/features/settings/ui/widgets/wallet_detail_fields.dart';
import 'package:bb_mobile/features/settings/ui/widgets/wallet_descriptor_details_bottom_sheet.dart';
import 'package:bb_mobile/features/settings/ui/widgets/wallet_policy_details_bottom_sheet.dart';
import 'package:bb_mobile/features/settings/ui/widgets/wallet_signer_details.dart';
import 'package:bb_mobile/features/settings/ui/widgets/wallet_deletion_confirmation_sheet.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show BullIcon, BullIcons, Gap;
import 'package:go_router/go_router.dart';

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
                  if (_usesDescriptorDetails(wallet))
                    _DescriptorWalletDetails(wallet: wallet)
                  else
                    _SingleSignerWalletDetails(wallet: wallet),
                  const Gap(32),
                  if (wallet.isBitcoin &&
                      wallet.signers.any(
                        (signer) =>
                            signer.signerDevice?.supportsWalletRegistration ??
                            false,
                      )) ...[
                    BBButton.big(
                      label: context.loc.walletRegistrationTitle,
                      onPressed: () => context.pushNamed(
                        SettingsRoute.walletRegistration.name,
                        pathParameters: {'walletId': wallet.id},
                      ),
                      bgColor: context.appColors.primary,
                      textColor: context.appColors.onPrimary,
                      iconData: Icons.devices_other,
                    ),
                    const Gap(16),
                  ],
                  BBButton.big(
                    label: context.loc.addressViewAddressesTitle,
                    onPressed: () => context.pushNamed(
                      SettingsRoute.walletAddresses.name,
                      pathParameters: {'walletId': wallet.id},
                    ),
                    bgColor: context.appColors.primary,
                    textColor: context.appColors.onPrimary,
                    iconData: Icons.chevron_right,
                  ),
                  if (wallet.isBitcoin &&
                      wallet.localMasterFingerprints.isNotEmpty) ...[
                    const Gap(16),
                    BBButton.big(
                      label: context.loc.psbtSigningTitle,
                      onPressed: () => context.pushNamed(
                        const PsbtSigningFacade().routeName,
                        pathParameters: {'walletId': wallet.id},
                      ),
                      bgColor: context.appColors.primary,
                      textColor: context.appColors.onPrimary,
                      iconData: Icons.draw_outlined,
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

bool _usesDescriptorDetails(Wallet wallet) =>
    wallet.scriptType == null || wallet.signers.length != 1;

class _SingleSignerWalletDetails extends StatelessWidget {
  final Wallet wallet;

  const _SingleSignerWalletDetails({required this.wallet});

  @override
  Widget build(BuildContext context) {
    final key = wallet.singleDescriptorKey!;
    final derivationPath = key.derivationPath ?? wallet.derivationPath;
    final signer = wallet.singleSigner!;
    final isUpdatingSignerDevice = context.select(
      (WalletDetailsCubit cubit) => cubit.state.isUpdatingSignerDevice,
    );
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        if (key.masterFingerprint.isNotEmpty) ...[
          WalletDetailInfoField(
            label: context.loc.walletDetailsWalletFingerprintLabel,
            value: key.masterFingerprint,
          ),
          const Gap(18),
        ],
        if (key.xpub.isNotEmpty) ...[
          WalletDetailCopyField(
            label: context.loc.walletDetailsPubkeyLabel,
            value: key.xpub,
            copyLabel: context.loc.walletDetailsCopyButton,
          ),
          const Gap(18),
        ],
        WalletDetailCopyField(
          label: context.loc.walletDetailsDescriptorLabel,
          value: wallet.publicDescriptor,
          copyLabel: context.loc.walletDetailsCopyButton,
        ),
        const Gap(18),
        WalletDetailInfoField(
          label: context.loc.walletDetailsAddressTypeLabel,
          value: wallet.addressType,
        ),
        const Gap(18),
        WalletDetailInfoField(
          label: context.loc.walletDetailsNetworkLabel,
          value: wallet.networkString,
        ),
        if (derivationPath != null) ...[
          const Gap(18),
          WalletDetailInfoField(
            label: context.loc.walletDetailsDerivationPathLabel,
            value: derivationPath,
          ),
        ],
        const Gap(18),
        if (signer.signer == SignerEntity.local || !wallet.isBitcoin) ...[
          WalletDetailInfoField(
            label: context.loc.walletDetailsSignerLabel,
            value: signer.signer.displayName,
          ),
          if (signer.signerDevice case final device?) ...[
            const Gap(18),
            WalletDetailInfoField(
              label: context.loc.walletDetailsSignerDeviceLabel,
              value: device.displayName,
            ),
          ],
        ] else ...[
          BBText(
            context.loc.walletDetailsSignerDeviceLabel,
            style: context.font.bodyMedium,
          ),
          const Gap(8),
          SignerDeviceDropdown(
            value: signer.signerDevice,
            unknownLabel: context.loc.importWatchOnlyUnknown,
            onChanged: isUpdatingSignerDevice
                ? null
                : (device) =>
                      context.read<WalletDetailsCubit>().updateSignerDevice(
                        walletId: wallet.id,
                        signerId: signer.id,
                        signerDevice: device,
                      ),
          ),
        ],
      ],
    );
  }
}

class _DescriptorWalletDetails extends StatelessWidget {
  final Wallet wallet;

  const _DescriptorWalletDetails({required this.wallet});

  @override
  Widget build(BuildContext context) {
    final policyState = context.watch<WalletDetailsCubit>().state;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        if (wallet.isBitcoin) ...[
          WalletDetailActionField(
            label: context.loc.walletDetailsSpendingConditionsLabel,
            value: policyState.isLoadingPolicy
                ? context.loc.walletDetailsLoadingLabel
                : policyState.failure != null
                ? context.loc.retry
                : policyState.policy == null
                ? context.loc.walletDetailsUnavailableLabel
                : context.loc.walletDetailsViewButton,
            onTap: policyState.isLoadingPolicy
                ? null
                : policyState.failure != null
                ? () => context.read<WalletDetailsCubit>().loadPolicy(wallet.id)
                : policyState.policy != null
                ? () => WalletPolicyDetailsBottomSheet.show(
                    context,
                    wallet: wallet,
                    policy: policyState.policy!,
                  )
                : null,
          ),
          const Gap(18),
        ],
        WalletDetailInfoField(
          label: context.loc.walletDetailsAddressTypeLabel,
          value: _descriptorAddressType(context, wallet),
        ),
        const Gap(18),
        WalletDetailInfoField(
          label: context.loc.walletDetailsNetworkLabel,
          value: wallet.networkString,
        ),
        const Gap(18),
        WalletDetailActionField(
          label: context.loc.walletDetailsDescriptorLabel,
          value: context.loc.walletDetailsViewButton,
          onTap: () => WalletDescriptorDetailsBottomSheet.show(context, wallet),
        ),
        if (wallet.signers.isNotEmpty) ...[
          const Gap(28),
          WalletSignerDetails(
            signers: wallet.signers,
            isUpdatingSignerDevice: policyState.isUpdatingSignerDevice,
            onSignerDeviceChanged: wallet.isBitcoin
                ? (signer, device) =>
                      context.read<WalletDetailsCubit>().updateSignerDevice(
                        walletId: wallet.id,
                        signerId: signer.id,
                        signerDevice: device,
                      )
                : null,
          ),
        ],
      ],
    );
  }
}

String _descriptorAddressType(BuildContext context, Wallet wallet) {
  final descriptor = wallet.publicDescriptor.trim().toLowerCase();
  if (descriptor.startsWith('sh(wsh(')) {
    return context.loc.walletDetailsNestedSegwitP2wsh;
  }
  if (descriptor.startsWith('sh(wpkh(')) {
    return context.loc.walletDetailsNestedSegwitP2wpkh;
  }
  if (descriptor.startsWith('wsh(')) {
    return context.loc.walletDetailsNativeSegwitP2wsh;
  }
  if (descriptor.startsWith('wpkh(')) {
    return context.loc.walletDetailsNativeSegwitP2wpkh;
  }
  if (descriptor.startsWith('pkh(')) {
    return context.loc.walletDetailsLegacyP2pkh;
  }
  if (descriptor.startsWith('sh(')) {
    return context.loc.walletDetailsLegacyP2sh;
  }
  return wallet.addressType;
}
