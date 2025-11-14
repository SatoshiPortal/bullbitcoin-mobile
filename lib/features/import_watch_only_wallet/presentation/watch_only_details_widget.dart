import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/labeled_text_input.dart';
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
        LabeledTextInput(
          label: context.loc.importWatchOnlyDescriptor,
          value: entity.descriptor.combined,
          onChanged: null,
        ),
        const Gap(24),
        LabeledTextInput(
          label: context.loc.importWatchOnlyType,
          value: entity.descriptor.derivation.label,
          onChanged: null,
        ),
        const Gap(24),
        if (entity.signerDevice == null)
          Row(
            children: [
              SizedBox(
                width: 120,
                child: BBText(
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
                    color: context.colour.secondary,
                  ),
                  value: entity.signerDevice,
                  items:
                      [null, ...SignerDeviceEntity.values]
                          .map(
                            (value) => DropdownMenuItem<SignerDeviceEntity?>(
                              value: value,
                              child: BBText(
                                value?.displayName ?? context.loc.importWatchOnlyUnknown,
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
          LabeledTextInput(
            label: context.loc.importWatchOnlySigningDevice,
            value: entity.signerDevice!.displayName,
            onChanged: null,
          ),
        const Gap(24),
        LabeledTextInput(
          label: context.loc.importWatchOnlyLabel,
          hint: context.loc.importWatchOnlyRequired,
          value: entity.label,
          onChanged: cubit.updateLabel,
          maxLines: 1,
        ),
        const Gap(24),
        BBButton.big(
          onPressed: cubit.import,
          label: context.loc.importWatchOnlyImport,
          bgColor: context.colour.secondary,
          textColor: context.colour.onSecondary,
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
        BBText(
          context.loc.importWatchOnlyExtendedPublicKey,
          style: context.font.titleMedium,
        ),
        const Gap(8),
        BBText(entity.pubkey, style: context.font.bodyMedium),
        const Gap(24),
        BBText(
          context.loc.importWatchOnlyType,
          style: context.font.titleMedium,
        ),
        const Gap(8),
        BBText(
          entity.extendedPubkey.derivation.label,
          style: context.font.bodyMedium,
        ),
        const Gap(24),
        BBText(
          context.loc.importWatchOnlyLabel,
          style: context.font.titleMedium,
        ),
        const Gap(8),
        BBInputText(
          onChanged: cubit.updateLabel,
          value: entity.label,
          maxLines: 1,
        ),
        const Gap(24),
        BBButton.big(
          onPressed: cubit.import,
          label: context.loc.importWatchOnlyImport,
          bgColor: context.colour.primary,
          textColor: context.colour.onPrimary,
        ),
        const Gap(24),
      ],
    );
  }
}
