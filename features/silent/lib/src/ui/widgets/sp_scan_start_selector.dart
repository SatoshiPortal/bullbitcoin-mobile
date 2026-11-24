import 'package:bull_ui/bull_ui.dart'
    show BullShapesX, BullThemeX, BullTypographyX, Gap;
import 'package:silent/src/presentation/silent_l10n.dart';
import 'package:silent/src/presentation/sp_setup_state.dart';
import 'package:material_ui/material_ui.dart';

/// Setup choice between a brand new SP wallet and one that already has history.
class SpScanStartSelector extends StatelessWidget {
  const SpScanStartSelector({
    super.key,
    required this.scanStart,
    required this.onChanged,
    required this.isBusy,
  });

  final SpScanStart scanStart;
  final ValueChanged<SpScanStart> onChanged;
  final bool isBusy;

  String _title(BuildContext context, SpScanStart value) => switch (value) {
    SpScanStart.fromNow => context.silentLoc.silentSetupScanFromNowTitle,
    SpScanStart.earlierBlock => context.silentLoc.silentSetupScanEarlierTitle,
  };

  String _subtitle(BuildContext context, SpScanStart value) => switch (value) {
    SpScanStart.fromNow => context.silentLoc.silentSetupScanFromNowSubtitle,
    SpScanStart.earlierBlock =>
      context.silentLoc.silentSetupScanEarlierSubtitle,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.silentLoc.silentSetupScanStartLabel,
          style: context.bullType.body,
        ),
        const Gap(4),
        RadioGroup<SpScanStart>(
          groupValue: scanStart,
          onChanged: (value) {
            if (isBusy || value == null) return;
            onChanged(value);
          },
          child: Column(
            children: [
              for (final value in SpScanStart.values) ...[
                RadioListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      context.bullShapes.card,
                    ),
                    side: BorderSide(color: context.bull.onSecondaryFixed),
                  ),
                  title: Text(
                    _title(context, value),
                    style: context.bullType.subtitle.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  subtitle: Text(
                    _subtitle(context, value),
                    style: context.bullType.label.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  value: value,
                ),
                const Gap(16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
