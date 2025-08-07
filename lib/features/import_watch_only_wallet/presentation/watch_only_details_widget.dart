import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/cubit/import_watch_only_cubit.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class WatchOnlyDetailsWidget extends StatelessWidget {
  const WatchOnlyDetailsWidget({
    required this.watchOnlyWallet,
    required this.cubit,
  });

  final WatchOnlyWalletEntity watchOnlyWallet;
  final ImportWatchOnlyCubit cubit;

  @override
  Widget build(BuildContext context) {
    return watchOnlyWallet.when(
      descriptor:
          (_, _, _) => _DescriptorDetailsWidget(
            entity: watchOnlyWallet as WatchOnlyDescriptorEntity,
            cubit: cubit,
          ),
      xpub:
          (_, _, _) => _XpubDetailsWidget(
            entity: watchOnlyWallet as WatchOnlyXpubEntity,
            cubit: cubit,
          ),
    );
  }
}

class _DescriptorDetailsWidget extends StatelessWidget {
  const _DescriptorDetailsWidget({required this.entity, required this.cubit});

  final WatchOnlyDescriptorEntity entity;
  final ImportWatchOnlyCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText('Descriptor', style: context.font.titleMedium),
        const Gap(8),
        BBText(entity.descriptor.combined, style: context.font.bodyMedium),
        const Gap(24),
        BBText('Type', style: context.font.titleMedium),
        const Gap(8),
        BBText(
          entity.descriptor.derivation.label,
          style: context.font.bodyMedium,
        ),
        const Gap(24),
        Row(
          children: [
            SizedBox(
              width: 120,
              child: BBText('Signing Device', style: context.font.titleMedium),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<SignerDeviceEntity?>(
                alignment: Alignment.centerLeft,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 24.0),
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: context.colour.secondary,
                ),
                value: entity.signerDevice,
                items:
                    [null, ...SignerDeviceEntity.values]
                        .map(
                          (value) => DropdownMenuItem<SignerDeviceEntity?>(
                            value: value,
                            child: BBText(
                              value?.displayName ?? 'Not supported',
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
        const Gap(24),
        BBText('Label', style: context.font.titleMedium),
        const Gap(8),
        BBInputText(
          onChanged: cubit.updateLabel,
          value: entity.label,
          maxLines: 1,
        ),
        const Gap(24),
        BBButton.big(
          onPressed: cubit.import,
          label: 'Import',
          bgColor: context.colour.primary,
          textColor: context.colour.onPrimary,
        ),
        const Gap(24),
      ],
    );
  }
}

class _XpubDetailsWidget extends StatelessWidget {
  const _XpubDetailsWidget({required this.entity, required this.cubit});

  final WatchOnlyXpubEntity entity;
  final ImportWatchOnlyCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText('Extended Public Key', style: context.font.titleMedium),
        const Gap(8),
        BBText(entity.pubkey, style: context.font.bodyMedium),
        const Gap(24),
        BBText('Type', style: context.font.titleMedium),
        const Gap(8),
        BBText(
          entity.extendedPubkey.derivation.label,
          style: context.font.bodyMedium,
        ),
        const Gap(24),
        BBText('Label', style: context.font.titleMedium),
        const Gap(8),
        BBInputText(
          onChanged: cubit.updateLabel,
          value: entity.label,
          maxLines: 1,
        ),
        const Gap(24),
        BBButton.big(
          onPressed: cubit.import,
          label: 'Import',
          bgColor: context.colour.primary,
          textColor: context.colour.onPrimary,
        ),
        const Gap(24),
      ],
    );
  }
}
