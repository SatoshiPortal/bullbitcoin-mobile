import 'package:bull_ui/bull_ui.dart' show BullInfoCard;
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Warns that the Blindbit server is behind the chain, so the last scan could
/// not see the newest blocks.
class SpBlindbitBehindCard extends StatelessWidget {
  const SpBlindbitBehindCard({required this.blocksBehind, super.key});

  final int blocksBehind;

  @override
  Widget build(BuildContext context) {
    return BullInfoCard(
      description: context.loc.spBlindbitBehindWarning(blocksBehind),
      tagColor: context.appColors.warning,
      bgColor: context.appColors.warningContainer,
    );
  }
}
