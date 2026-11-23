import 'package:bull_ui/bull_ui.dart' show BullInfoCard, BullThemeX;
import 'package:silent/src/presentation/silent_l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Warns that the Blindbit server is behind the chain, so the last scan could
/// not see the newest blocks.
class SpBlindbitBehindCard extends StatelessWidget {
  const SpBlindbitBehindCard({required this.blocksBehind, super.key});

  final int blocksBehind;

  @override
  Widget build(BuildContext context) {
    return BullInfoCard(
      description: context.silentLoc.silentBlindbitBehindWarning(blocksBehind),
      tagColor: context.bull.warning,
      bgColor: context.bull.warningContainer,
    );
  }
}
