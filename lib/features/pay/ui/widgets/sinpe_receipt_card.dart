import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:gif/gif.dart';

String formatSinpePhoneNumber(String? phoneNumber, String fallback) {
  if (phoneNumber == null || phoneNumber.isEmpty) {
    return fallback;
  }

  // Remove any existing formatting
  final String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

  // Add +506 prefix
  final String formattedNumber = '+506$cleanNumber';

  // Add dashes every 4 digits after the prefix
  if (cleanNumber.length >= 4) {
    const String prefix = '+506';
    final String number = cleanNumber;
    final StringBuffer formatted = StringBuffer(prefix);

    for (int i = 0; i < number.length; i += 4) {
      final int end = (i + 4 < number.length) ? i + 4 : number.length;
      formatted.write('-${number.substring(i, end)}');
    }

    return formatted.toString();
  }

  return formattedNumber;
}

class SinpeReceiptCard extends StatelessWidget {
  const SinpeReceiptCard({
    super.key,
    required this.order,
    this.showSuccessAnimation = true,
  });

  final FiatPaymentOrder order;
  final bool showSuccessAnimation;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(24.0),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSuccessAnimation) ...[
              Gif(
                image: AssetImage(Assets.animations.successTick.path),
                autostart: Autostart.once,
                width: 150,
                height: 150,
              ),
              Text(
                context.loc.paySinpeEnviado,
                style: context.font.headlineLarge?.copyWith(
                  color: context.appColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Gap(16),
            ],
            Text(context.loc.paySinpeMonto, style: context.font.bodyMedium),
            const Gap(4),
            Text(
              '${order.payoutAmount.toStringAsFixed(2)} ${order.payoutCurrency}',
              style: context.font.headlineSmall?.copyWith(
                color: context.appColors.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Gap(8),
            Text(
              context.loc.paySinpeNumeroOrden,
              style: context.font.bodyMedium,
            ),
            const Gap(4),
            Text(
              order.orderNumber.toString(),
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Gap(8),
            Text(
              context.loc.paySinpeNumeroComprobante,
              style: context.font.bodyMedium,
            ),
            const Gap(4),
            Text(
              order.referenceNumber ?? context.loc.payNotAvailable,
              style: context.font.headlineSmall?.copyWith(
                color: context.appColors.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Gap(8),
            Text(
              context.loc.paySinpeBeneficiario,
              style: context.font.bodyMedium,
            ),
            const Gap(4),
            Text(
              order.beneficiaryName ?? context.loc.payNotAvailable,
              style: context.font.headlineSmall?.copyWith(
                color: context.appColors.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Gap(4),
            Text(
              formatSinpePhoneNumber(
                order.beneficiaryAccountNumber,
                context.loc.payNotAvailable,
              ),
              style: context.font.headlineSmall?.copyWith(
                color: context.appColors.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Gap(8),
            Text(context.loc.paySinpeOrigen, style: context.font.bodyMedium),
            const Gap(4),
            Text(
              order.originName ?? context.loc.payNotAvailable,
              style: context.font.headlineSmall?.copyWith(
                color: context.appColors.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Gap(4),
            Text(
              order.originCedula ?? context.loc.payNotAvailable,
              style: context.font.headlineSmall?.copyWith(
                color: context.appColors.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
