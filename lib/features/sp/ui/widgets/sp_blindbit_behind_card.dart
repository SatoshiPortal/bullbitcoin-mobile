import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:flutter/material.dart';

/// Warns that the Blindbit server is behind the chain, so the last scan could
/// not see the newest blocks.
class SpBlindbitBehindCard extends StatelessWidget {
  const SpBlindbitBehindCard({required this.blocksBehind, super.key});

  final int blocksBehind;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      description: context.loc.spBlindbitBehindWarning(blocksBehind),
      tagColor: context.appColors.warning,
      bgColor: context.appColors.warningContainer,
    );
  }
}
