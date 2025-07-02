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
        const Gap(24),
        BBText('Extended Public Key', style: context.font.titleMedium),
        const Gap(8),
        BBText(watchOnlyWallet.watchOnly.descriptor.pubkey, style: null),
        const Gap(16),
        BBText('Type', style: context.font.titleMedium),
        const Gap(8),
        BBText(
          watchOnlyWallet.watchOnly.descriptor.derivation.label,
          style: null,
        ),
        const Gap(16),
        BBText('Fingerprint', style: context.font.titleMedium),
        const Gap(8),
        BBInputText(
          onChanged: cubit.overrideFingerprint,
          value: watchOnlyWallet.watchOnly.descriptor.fingerprint,
          maxLines: 1,
          hint: 'fingerprint',
          maxLength: 8,
        ),
        const Gap(16),
        DropdownButtonFormField<WalletSource>(
          alignment: Alignment.centerLeft,
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
          ),
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: context.colour.secondary,
          ),
          value: WalletSource.xpub,
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

        const Gap(16),
        BBText('Label', style: context.font.titleMedium),
        const Gap(8),
        BBInputText(
          onChanged: cubit.updateLabel,
          value: watchOnlyWallet.label,
          hint: 'label (optional)',
          maxLines: 1,
        ),
        const Gap(16),
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
