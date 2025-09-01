import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/dca/domain/dca_wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class DcaWalletRadioList extends StatelessWidget {
  const DcaWalletRadioList({
    super.key,
    this.selectedWallet,
    this.onChanged,
    this.errorText,
  });

  final DcaWalletType? selectedWallet;
  final ValueChanged<DcaWalletType?>? onChanged;
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
        ...DcaWalletType.values.map((walletType) {
          return Column(
            children: [
              RadioListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: borderColor),
                ),
                title: Text(switch (walletType) {
                  DcaWalletType.bitcoin => 'Bitcoin (BTC)',
                  DcaWalletType.lightning => 'Lightning Network (LN)',
                  DcaWalletType.liquid => 'Liquid (LBTC)',
                }, style: context.font.headlineSmall),
                subtitle: Text(switch (walletType) {
                  DcaWalletType.bitcoin => 'Minimum 0.001 BTC',
                  DcaWalletType.lightning =>
                    'Requires compatible wallet, maximum 0.25 BTC',
                  DcaWalletType.liquid => 'Requires compatible wallet',
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
