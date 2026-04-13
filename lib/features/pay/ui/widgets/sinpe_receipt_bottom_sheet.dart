import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/features/pay/ui/widgets/sinpe_receipt_card.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

Future<void> showSinpeReceiptBottomSheet(
  BuildContext context,
  FiatPaymentOrder order,
) async {
  await BlurredBottomSheet.show(
    context: context,
    child: SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Gap(12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appColors.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Gap(16),
              Row(
                children: [
                  const Spacer(),
                  Text(
                    context.loc.paySinpeReceipt,
                    style: context.font.headlineMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => context.pop(),
                    color: context.appColors.onSurface,
                    icon: const Icon(Icons.close_sharp),
                  ),
                ],
              ),
              SinpeReceiptCard(order: order, showSuccessAnimation: false),
              const Gap(16),
            ],
          ),
        ),
      ),
    ),
  );
}
