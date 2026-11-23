import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:exchange/exchange.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart' show BullShapesX, Gap, BullTypographyX;

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
    final borderColor = hasError
        ? context.appColors.error
        : context.appColors.onSecondaryFixed;

    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [
        Text(
          context.loc.dcaSelectWalletTypeLabel,
          style: context.bullType.body,
        ),
        const Gap(4),
        RadioGroup<DcaNetwork>(
          groupValue: selectedWallet,
          onChanged: onChanged ?? (_) {},
          child: Column(
            children: DcaNetwork.values.map((walletType) {
              return Column(
                children: [
                  RadioListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        context.bullShapes.card,
                      ),
                      side: BorderSide(color: borderColor),
                    ),
                    title: Text(
                      switch (walletType) {
                        DcaNetwork.bitcoin => context.loc.dcaWalletTypeBitcoin,
                        DcaNetwork.lightning =>
                          context.loc.dcaWalletTypeLightning,
                        DcaNetwork.liquid => context.loc.dcaWalletTypeLiquid,
                      },
                      style: context.bullType.subtitle.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    subtitle: Text(
                      switch (walletType) {
                        DcaNetwork.bitcoin =>
                          context.loc.dcaWalletBitcoinSubtitle,
                        DcaNetwork.lightning =>
                          context.loc.dcaWalletLightningSubtitle,
                        DcaNetwork.liquid =>
                          context.loc.dcaWalletLiquidSubtitle,
                      },
                      style: context.bullType.label.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
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
            style: context.bullType.label
                .copyWith(fontWeight: FontWeight.w400)
                .copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}
