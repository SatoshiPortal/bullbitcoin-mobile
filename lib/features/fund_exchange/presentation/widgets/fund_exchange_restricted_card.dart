import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart' show BullInfoCard;

class FundExchangeRestrictedCard extends StatelessWidget {
  const FundExchangeRestrictedCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BullInfoCard(
      title: context.loc.fundExchangeRestrictedTitle,
      description: context.loc.fundExchangeRestrictedMessage,
      bgColor: context.appColors.error.withValues(alpha: 0.1),
      tagColor: context.appColors.error,
    );
  }
}
