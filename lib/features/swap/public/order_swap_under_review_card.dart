import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/exchange_support_chat/public/exchange_support_chat_facade.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_record.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
        BBText(
          context.loc.swapUnderReviewTitle,
          style: context.font.titleMedium,
          textAlign: TextAlign.center,
        ),
        const Gap(8),
        InfoCard(
          description: context.loc.swapUnderReviewDescription,
          tagColor: context.appColors.tertiary,
          bgColor: context.appColors.warningContainer,
          boldDescription: true,
        ),
        const Gap(12),
        BBButton.big(
          label: context.loc.swapUnderReviewContactSupport,
          onPressed: () {
            final message = context.loc.swapUnderReviewSupportMessage(
              order.orderId,
              requestId,
              order.orderNumber,
            );
            context.pushNamed(
              ExchangeSupportChatFacade.routeName,
              extra: ExchangeSupportChatDraft(initialMessage: message),
            );
          },
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
      ],
    );
  }
}
