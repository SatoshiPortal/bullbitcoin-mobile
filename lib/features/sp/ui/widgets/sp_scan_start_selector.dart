import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_state.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

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
    SpScanStart.fromNow => context.loc.spSetupScanFromNowTitle,
    SpScanStart.earlierBlock => context.loc.spSetupScanEarlierTitle,
  };

  String _subtitle(BuildContext context, SpScanStart value) => switch (value) {
    SpScanStart.fromNow => context.loc.spSetupScanFromNowSubtitle,
    SpScanStart.earlierBlock => context.loc.spSetupScanEarlierSubtitle,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.loc.spSetupScanStartLabel, style: context.font.bodyMedium),
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
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: context.appColors.onSecondaryFixed),
                  ),
                  title: Text(
                    _title(context, value),
                    style: context.font.headlineSmall,
                  ),
                  subtitle: Text(
                    _subtitle(context, value),
                    style: context.font.bodySmall,
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
