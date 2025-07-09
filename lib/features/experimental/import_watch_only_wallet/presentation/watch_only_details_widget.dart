import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/presentation/cubit/import_watch_only_cubit.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/inputs/text_input.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
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
              width: 100,
              child: BBText('Source', style: context.font.titleMedium),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<WalletSource>(
                alignment: Alignment.centerLeft,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 24.0),
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: context.colour.secondary,
                ),
                value: entity.source,
                items:
                    [WalletSource.descriptors, WalletSource.coldcard]
                        .map(
                          (source) => DropdownMenuItem<WalletSource>(
                            value: source,
                            child: BBText(
                              source.name,
                              style: context.font.headlineSmall,
                            ),
                          ),
                        )
                        .toList(),
                onChanged: cubit.onSourceChanged,
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
        Row(
          children: [
            SizedBox(
              width: 100,
              child: BBText('Source', style: context.font.titleMedium),
            ),
            SizedBox(
              width: 200,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                child: BBText(
                  entity.source.name,
                  style: context.font.headlineSmall,
                ),
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
