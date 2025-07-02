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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText('Extended Public Key', style: context.font.titleMedium),
        const Gap(8),
        BBText(watchOnlyWallet.descriptor.pubkey, style: null),
        const Gap(24),
        BBText(
          '${watchOnlyWallet.descriptor.derivation.label} Descriptor',
          style: context.font.titleMedium,
        ),
        const Gap(8),
        BBText(watchOnlyWallet.descriptor.combined, style: null),
        const Gap(24),
        BBText('Override Master fingerprint', style: context.font.titleMedium),
        const Gap(8),
        BBText(
          'Is able to generate Psbt?    ${watchOnlyWallet.canGenerateValidPsbt ? 'Yes' : 'No'}',
          style: null,
        ),
        const Gap(8),
        BBText(
          'Pubkey Fingerprint:    ${watchOnlyWallet.pubkeyFingerprint}',
          style: null,
        ),
        const Gap(8),
        SizedBox(
          width: 150,
          child: BBInputText(
            onChanged: cubit.overrideMasterFingerprint,
            value: cubit.state.overrideMasterFingerprint,
            maxLines: 1,
            hint: 'fingerprint',
            maxLength: 8,
          ),
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
                value: watchOnlyWallet.source,
                items:
                    WalletSource.values
                        .where((e) => e != WalletSource.mnemonic)
                        .map(
                          (language) => DropdownMenuItem<WalletSource>(
                            value: language,
                            child: BBText(
                              language.name,
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
          value: watchOnlyWallet.label,
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
