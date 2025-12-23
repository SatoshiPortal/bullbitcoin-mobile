import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:flutter/material.dart';

class FundExchangeDetailsErrorCard extends StatelessWidget {
  const FundExchangeDetailsErrorCard({super.key});

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      description: context.loc.fundExchangeErrorLoadingDetails,
      bgColor: context.appColors.error.withValues(alpha: 0.1),
      tagColor: context.appColors.primary,
    );
  }
}
