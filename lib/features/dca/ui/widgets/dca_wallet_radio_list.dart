import 'package:bb_mobile/core/themes/app_theme.dart';
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
        hasError ? context.colour.error : context.colour.onSecondaryFixed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Select Bitcoin wallet type', style: context.font.bodyMedium),
        const Gap(4),
        ...DcaNetwork.values.map((walletType) {
          return Column(
            children: [
              RadioListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: borderColor),
                ),
                title: Text(switch (walletType) {
                  DcaNetwork.bitcoin => 'Bitcoin (BTC)',
                  DcaNetwork.lightning => 'Lightning Network (LN)',
                  DcaNetwork.liquid => 'Liquid (LBTC)',
                }, style: context.font.headlineSmall),
                subtitle: Text(switch (walletType) {
                  DcaNetwork.bitcoin => 'Minimum 0.001 BTC',
                  DcaNetwork.lightning =>
                    'Requires compatible wallet, maximum 0.25 BTC',
                  DcaNetwork.liquid => 'Requires compatible wallet',
                }, style: context.font.bodySmall),
                value: walletType,
                groupValue: selectedWallet,
                onChanged: onChanged,
              ),
              const Gap(16),
            ],
          );
        }),
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
