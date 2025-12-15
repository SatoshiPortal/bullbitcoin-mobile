import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/widgets/cards/info_card.dart';
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
