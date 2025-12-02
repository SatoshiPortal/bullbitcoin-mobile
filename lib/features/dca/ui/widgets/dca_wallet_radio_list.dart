import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/dca/domain/dca.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class DcaWalletRadioList extends StatelessWidget {
  const DcaWalletRadioList({
    super.key,
    this.selectedWallet,
    this.onChanged,
    this.errorText,
  });

  final DcaNetwork? selectedWallet;
  final ValueChanged<DcaNetwork?>? onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;
    final borderColor =
        hasError
            ? context.appColors.error
            : context.appColors.onSecondaryFixed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.loc.dcaSelectWalletTypeLabel,
          style: context.font.bodyMedium,
        ),
        const Gap(4),
        RadioGroup<DcaNetwork>(
          groupValue: selectedWallet,
          onChanged: onChanged ?? (_) {},
          child: Column(
            children:
                DcaNetwork.values.map((walletType) {
                  return Column(
                    children: [
                      RadioListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: borderColor),
                        ),
                        title: Text(switch (walletType) {
                          DcaNetwork.bitcoin => context.loc.dcaWalletTypeBitcoin,
                          DcaNetwork.lightning => context.loc.dcaWalletTypeLightning,
                          DcaNetwork.liquid => context.loc.dcaWalletTypeLiquid,
                        }, style: context.font.headlineSmall),
                        subtitle: Text(switch (walletType) {
                          DcaNetwork.bitcoin => context.loc.dcaWalletBitcoinSubtitle,
                          DcaNetwork.lightning =>
                            context.loc.dcaWalletLightningSubtitle,
                          DcaNetwork.liquid => context.loc.dcaWalletLiquidSubtitle,
                        }, style: context.font.bodySmall),
                        value: walletType,
                      ),
                      const Gap(16),
                    ],
                  );
                }).toList(),
          ),
        ),
        if (hasError) ...[
          const Gap(4),
          Text(
            errorText!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
