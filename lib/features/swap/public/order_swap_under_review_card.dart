import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_record.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullInfoCard, BullSupportButton, BullText, Gap, BullTypographyX;
import 'package:material_ui/material_ui.dart';

class OrderSwapUnderReviewCard extends StatelessWidget {
  final OrderSwapRecord orderSwap;

  const OrderSwapUnderReviewCard({super.key, required this.orderSwap});

  @override
  Widget build(BuildContext context) {
    final order = orderSwap.order;
    final requestId = orderSwap.requestId;
    if (order == null || requestId == null || !order.requiresManualReview) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BullText(
          context.loc.swapUnderReviewTitle,
          style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        const Gap(8),
        BullInfoCard(
          description: context.loc.swapUnderReviewDescription,
          tagColor: context.appColors.tertiary,
          bgColor: context.appColors.warningContainer,
          boldDescription: true,
        ),
        const Gap(12),
        BullSupportButton.big(
          label: context.loc.swapUnderReviewContactSupport,
          message: context.loc.swapUnderReviewSupportMessage(
            order.orderId,
            requestId,
            order.orderNumber,
          ),
        ),
      ],
    );
  }
}
