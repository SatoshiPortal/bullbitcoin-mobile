import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/labeled_text_input.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/cubit/import_watch_only_cubit.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
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
    final watchOnlyWallet =
        context.watch<ImportWatchOnlyCubit>().state.watchOnlyWallet;
    final entity = watchOnlyWallet! as WatchOnlyDescriptorEntity;

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
                    color: context.appColors.text,
                  ),
                  value: entity.signerDevice,
                  items:
                      [null, ...SignerDeviceEntity.values]
                          .map(
                            (value) => DropdownMenuItem<SignerDeviceEntity?>(
                              value: value,
                              child: BBText(
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
          bgColor: context.appColors.onSurface,
          textColor: context.appColors.surface,
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
    final watchOnlyWallet =
        context.watch<ImportWatchOnlyCubit>().state.watchOnlyWallet;
    final entity = watchOnlyWallet! as WatchOnlyXpubEntity;
    final isXpub = entity.pubkey.startsWith('xpub');

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
        if (!isXpub) ...[
          BBText('XPUB', style: context.font.titleMedium),
          const Gap(8),
          BBText(
            entity.watchOnlyXpub.extendedPubkey.xpub,
            style: context.font.bodyMedium,
          ),
          const Gap(24),
        ],
        BBText('Type', style: context.font.titleMedium),
        const Gap(8),
        if (!isXpub) ...[
          BBText(
            entity.extendedPubkey.derivation.label,
            style: context.font.bodyMedium,
          ),
          const Gap(24),
        ] else ...[
          InfoCard(
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
              value: entity.extendedPubkey.derivation,
              items:
                  [...satoshifier.Derivation.values]
                      .map(
                        (value) => DropdownMenuItem<satoshifier.Derivation>(
                          value: value,
                          child: BBText(
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
          label: context.loc.importWatchOnlyImport,
          bgColor: context.appColors.primary,
          textColor: context.appColors.onPrimary,
        ),
        const Gap(24),
      ],
    );
  }
}
