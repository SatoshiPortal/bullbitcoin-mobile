import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullQrCode, BullBottomSheet, BullText, Gap, BullTypographyX;

class SellQrBottomSheet extends StatelessWidget {
  const SellQrBottomSheet({super.key, required this.bip21InvoiceData});

  final String bip21InvoiceData;

  static Future<void> show(
    BuildContext context,
    String bip21InvoiceData,
  ) async {
    await BullBottomSheet.show(
      context: context,
      child: SellQrBottomSheet(bip21InvoiceData: bip21InvoiceData),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (bip21InvoiceData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: BullText(
            context.loc.sellNoInvoiceData,
            style: context.bullType.body,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              BullText(
                context.loc.sellQrCode,
                style: context.bullType.subtitle.copyWith(
                  fontWeight: FontWeight.w400,
                ),
                color: context.appColors.secondary,
              ),
              IconButton(
                tooltip: context.loc.closeDialogButton,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Gap(24),
          Center(
            child: BullQrCode(
              data: bip21InvoiceData,
              size: 280,
              semanticsLabel: context.loc.sellQrCode,
            ),
          ),
          const Gap(16),
        ],
      ),
    );
  }
}
