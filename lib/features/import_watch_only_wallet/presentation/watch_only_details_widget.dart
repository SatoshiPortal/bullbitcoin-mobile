import 'package:signers/signers.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/cubit/import_watch_only_cubit.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullDropdown,
        BullInfoCard,
        BullInputText,
        BullLabeledTextInput,
        BullPickerItem,
        BullText,
        Gap,
        BullTypographyX;
import 'package:satoshifier/satoshifier.dart' as satoshifier;

class WatchOnlyDetailsWidget extends StatelessWidget {
  final WatchOnlyWalletEntity watchOnlyWallet;
  const WatchOnlyDetailsWidget({super.key, required this.watchOnlyWallet});

  @override
  Widget build(BuildContext context) {
    return watchOnlyWallet.when(
      descriptor: (_, _, _) => const _DescriptorDetailsWidget(),
      xpub: (_, _, _) => const _XpubDetailsWidget(),
    );
  }
}

class _DescriptorDetailsWidget extends StatelessWidget {
  const _DescriptorDetailsWidget();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ImportWatchOnlyCubit>();
    final watchOnlyWallet = context
        .watch<ImportWatchOnlyCubit>()
        .state
        .watchOnlyWallet;
    if (watchOnlyWallet is! WatchOnlyDescriptorEntity) {
      return const SizedBox.shrink();
    }
    final entity = watchOnlyWallet;
    final networkLabel = switch (entity.network) {
      Network.bitcoinMainnet =>
        context.loc.importWatchOnlyNetworkBitcoinMainnet,
      Network.bitcoinTestnet =>
        context.loc.importWatchOnlyNetworkBitcoinTestnet,
      Network.bitcoinRegtest => context.loc.electrumRegtest,
      Network.liquidMainnet ||
      Network.liquidTestnet ||
      Network.liquidRegtest => throw StateError(
        'Liquid watch-only wallets must be rejected before presentation',
      ),
    };

    return Column(
      crossAxisAlignment: .start,
      children: [
        BullText(networkLabel, style: context.bullType.body),
        const Gap(24),
        BullLabeledTextInput(
          label: context.loc.importWatchOnlyDescriptor,
          value: entity.descriptor.combined,
          onChanged: null,
        ),
        const Gap(24),
        BullLabeledTextInput(
          label: context.loc.importWatchOnlyType,
          value: entity.descriptor.derivation.label,
          onChanged: null,
        ),
        const Gap(24),
        if (entity.network != Network.bitcoinRegtest &&
            entity.signerDevice == null)
          Row(
            children: [
              SizedBox(
                width: 120,
                child: BullText(
                  context.loc.importWatchOnlySigningDevice,
                  style: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: BullDropdown<SignerDevice?>(
                  value: entity.signerDevice,
                  items: [
                    for (final value in [null, ...SignerDevice.values])
                      BullPickerItem<SignerDevice?>(
                        value: value,
                        label:
                            value?.displayName ??
                            context.loc.importWatchOnlyUnknown,
                      ),
                  ],
                  onChanged: cubit.onSignerDeviceChanged,
                ),
              ),
            ],
          ),
        if (entity.network != Network.bitcoinRegtest)
          if (entity.signerDevice case final device?)
            BullLabeledTextInput(
              label: context.loc.importWatchOnlySigningDevice,
              value: device.displayName,
              onChanged: null,
            ),
        const Gap(24),
        BullLabeledTextInput(
          label: context.loc.importWatchOnlyLabel,
          hint: context.loc.importWatchOnlyRequired,
          value: entity.label,
          onChanged: cubit.updateLabel,
          maxLines: 1,
        ),
        const Gap(24),
        BullButton.primary(
          onPressed: cubit.import,
          label: context.loc.importWatchOnlyImport,
        ),
        const Gap(24),
      ],
    );
  }
}

class _XpubDetailsWidget extends StatelessWidget {
  const _XpubDetailsWidget();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ImportWatchOnlyCubit>();
    final watchOnlyWallet = context
        .watch<ImportWatchOnlyCubit>()
        .state
        .watchOnlyWallet;
    if (watchOnlyWallet is! WatchOnlyXpubEntity) return const SizedBox.shrink();
    final entity = watchOnlyWallet;
    final isXpub = entity.pubkey.startsWith('xpub');

    return Column(
      crossAxisAlignment: .start,
      children: [
        BullText(
          context.loc.importWatchOnlyExtendedPublicKey,
          style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
        ),
        const Gap(8),
        BullText(entity.pubkey, style: context.bullType.body),
        const Gap(24),
        if (!isXpub) ...[
          BullText(
            context.loc.importWatchOnlyXpubLabel,
            style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
          ),
          const Gap(8),
          BullText(entity.bip32Pubkey, style: context.bullType.body),
          const Gap(24),
        ],
        BullText(
          context.loc.importWatchOnlyType,
          style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
        ),
        const Gap(8),
        if (!isXpub) ...[
          BullText(
            entity.extendedPubkey.derivation.label,
            style: context.bullType.body,
          ),
          const Gap(24),
        ] else ...[
          BullInfoCard(
            title: context.loc.importWatchOnlyDisclaimerTitle,
            description: context.loc.importWatchOnlyDisclaimerDescription,
            bgColor: context.appColors.warning.withValues(alpha: 0.1),
            tagColor: context.appColors.warning,
          ),
          SizedBox(
            width: 260,
            child: BullDropdown<satoshifier.Derivation>(
              value: entity.extendedPubkey.derivation,
              items: [
                for (final value in satoshifier.Derivation.values)
                  BullPickerItem(
                    value: value,
                    label: 'BIP${value.purpose} - ${value.label}',
                  ),
              ],
              onChanged: cubit.onDerivationChanged,
            ),
          ),
          const Gap(24),
        ],
        BullText(
          context.loc.importWatchOnlyLabel,
          style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
        ),
        const Gap(8),
        BullInputText(
          onChanged: cubit.updateLabel,
          value: entity.label,
          maxLines: 1,
        ),
        const Gap(24),
        BullButton.primary(
          onPressed: cubit.import,
          label: context.loc.importWatchOnlyImport,
        ),
        const Gap(24),
      ],
    );
  }
}
