import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/samrock/domain/entities/samrock_setup.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class SamrockConfirmationWidget extends StatelessWidget {
  final SamrockSetupRequest request;

  const SamrockConfirmationWidget({
    super.key,
    required this.request,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBText(
            'Connect to BTCPay Server',
            style: context.font.headlineMedium,
          ),
          const Gap(16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.appColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText(
                  'Server',
                  style: context.font.labelSmall,
                  color: context.appColors.textMuted,
                ),
                const Gap(4),
                BBText(
                  request.serverHost,
                  style: context.font.bodyLarge,
                ),
              ],
            ),
          ),
          const Gap(16),
          BBText(
            'Payment methods to configure:',
            style: context.font.bodyMedium,
            color: context.appColors.textMuted,
          ),
          const Gap(8),
          ...request.paymentMethods.map(
            (method) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _iconForMethod(method),
                    size: 20,
                    color: context.appColors.primary,
                  ),
                  const Gap(8),
                  BBText(
                    method.displayName,
                    style: context.font.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const Gap(16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.appColors.border),
            ),
            child: BBText(
              'This will share your public wallet descriptors with the server so it can generate receive addresses for your store.',
              style: context.font.bodySmall,
              color: context.appColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForMethod(SamrockPaymentMethod method) {
    switch (method) {
      case SamrockPaymentMethod.btc:
        return Icons.currency_bitcoin;
      case SamrockPaymentMethod.lbtc:
        return Icons.water_drop_outlined;
      case SamrockPaymentMethod.btcln:
        return Icons.flash_on;
    }
  }
}
