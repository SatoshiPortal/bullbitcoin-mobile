import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:qr_flutter/qr_flutter.dart';

class SellQrBottomSheet extends StatelessWidget {
  const SellQrBottomSheet({super.key, required this.bip21InvoiceData});

  final String bip21InvoiceData;

  static Future<void> show(
    BuildContext context,
    String bip21InvoiceData,
  ) async {
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.colour.onPrimary,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      isScrollControlled: true,
      builder: (context) {
        return SellQrBottomSheet(bip21InvoiceData: bip21InvoiceData);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (bip21InvoiceData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: BBText(
            'No invoice data available',
            style: context.font.bodyMedium,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BBText('QR Code', style: context.font.headlineSmall),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Gap(24),
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SizedBox(
                width: 280,
                height: 280,
                child: QrImageView(data: bip21InvoiceData, size: 280),
              ),
            ),
          ),
          const Gap(16),
        ],
      ),
    );
  }
}
