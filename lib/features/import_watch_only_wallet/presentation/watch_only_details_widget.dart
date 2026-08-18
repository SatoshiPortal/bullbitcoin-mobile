import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/cubit/import_watch_only_cubit.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:satoshifier/enums/derivation.dart' as satoshifier;

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
    final entity = watchOnlyWallet! as WatchOnlyDescriptorEntity;

    return Column(
      crossAxisAlignment: .start,
      children: [
        BullText(
          'Network: ${entity.network.name}',
          style: context.font.bodyMedium,
        ),
        const Gap(24),
        _ReadOnlyInput(
          label: context.loc.importWatchOnlyDescriptor,
          value: entity.descriptor.combined,
        ),
        const Gap(24),
        _ReadOnlyInput(
          label: context.loc.importWatchOnlyType,
          value: entity.descriptor.derivation.label,
        ),
        const Gap(24),
        if (entity.signerDevice == null)
          Row(
            children: [
              SizedBox(
                width: 120,
                child: BullText(
                  context.loc.importWatchOnlySigningDevice,
                  style: context.font.titleMedium,
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<SignerDeviceEntity?>(
                  alignment: Alignment.centerLeft,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 24.0),
                  ),
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: context.appColors.text,
                  ),
                  initialValue: entity.signerDevice,
                  items: [null, ...SignerDeviceEntity.values]
                      .map(
                        (value) => DropdownMenuItem<SignerDeviceEntity?>(
                          value: value,
                          child: BullText(
                            value?.displayName ??
                                context.loc.importWatchOnlyUnknown,
                            style: context.font.headlineSmall,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: cubit.onSignerDeviceChanged,
                ),
              ),
            ],
          ),
        if (entity.signerDevice != null)
          _ReadOnlyInput(
            label: context.loc.importWatchOnlySigningDevice,
            value: entity.signerDevice!.displayName,
          ),
        const Gap(24),
        BullText(
          context.loc.importWatchOnlyLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Gap(8),
        BullInputText(
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
    final entity = watchOnlyWallet! as WatchOnlyXpubEntity;
    final isXpub = entity.pubkey.startsWith('xpub');

    return Column(
      crossAxisAlignment: .start,
      children: [
        BullText(
          context.loc.importWatchOnlyExtendedPublicKey,
          style: context.font.titleMedium,
        ),
        const Gap(8),
        BullText(entity.pubkey, style: context.font.bodyMedium),
        const Gap(24),
        if (!isXpub) ...[
          BullText(
            context.loc.importWatchOnlyXpubLabel,
            style: context.font.titleMedium,
          ),
          const Gap(8),
          BullText(
            entity.watchOnlyXpub.extendedPubkey.xpub,
            style: context.font.bodyMedium,
          ),
          const Gap(24),
        ],
        BullText(
          context.loc.importWatchOnlyType,
          style: context.font.titleMedium,
        ),
        const Gap(8),
        if (!isXpub) ...[
          BullText(
            entity.extendedPubkey.derivation.label,
            style: context.font.bodyMedium,
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
            child: DropdownButtonFormField<satoshifier.Derivation>(
              alignment: Alignment.centerLeft,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 24.0),
              ),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: context.appColors.text,
              ),
              initialValue: entity.extendedPubkey.derivation,
              items: [...satoshifier.Derivation.values]
                  .map(
                    (value) => DropdownMenuItem<satoshifier.Derivation>(
                      value: value,
                      child: BullText(
                        'BIP${value.purpose} - ${value.label}',
                        style: context.font.headlineSmall,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: cubit.onDerivationChanged,
            ),
          ),
          const Gap(24),
        ],
        BullText(
          context.loc.importWatchOnlyLabel,
          style: context.font.titleMedium,
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

class _ReadOnlyInput extends StatelessWidget {
  const _ReadOnlyInput({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BullText(label, style: Theme.of(context).textTheme.titleMedium),
        const Gap(8),
        BullInputText(
          value: value,
          onChanged: (_) {},
          disabled: true,
          maxLines: 3,
        ),
      ],
    );
  }
}
