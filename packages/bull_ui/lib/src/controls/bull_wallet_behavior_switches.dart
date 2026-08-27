import 'package:flutter/material.dart';

/// A generic pair of coupled wallet-behavior switches.
///
/// The application owns the behavior invariant and supplies every piece of
/// product copy. The component only enforces the supplied availability state
/// while always allowing an already-hidden wallet to be made visible again.
class BullWalletBehaviorSwitches extends StatelessWidget {
  const BullWalletBehaviorSwitches({
    super.key,
    required this.hideOnHome,
    required this.autoSweepEnabled,
    required this.canHideOnHome,
    required this.saving,
    required this.autoSweepLabel,
    required this.hideOnHomeLabel,
    required this.hideOnHomeUnavailableInfo,
    required this.onAutoSweepChanged,
    required this.onHideOnHomeChanged,
    this.autoSweepInfo,
    this.hideOnHomeInfo,
    this.autoSweepSwitchKey,
    this.hideOnHomeSwitchKey,
  });

  final bool hideOnHome;
  final bool autoSweepEnabled;
  final bool canHideOnHome;
  final bool saving;
  final String autoSweepLabel;
  final String hideOnHomeLabel;
  final String hideOnHomeUnavailableInfo;
  final String? autoSweepInfo;
  final String? hideOnHomeInfo;
  final Key? autoSweepSwitchKey;
  final Key? hideOnHomeSwitchKey;
  final ValueChanged<bool> onAutoSweepChanged;
  final ValueChanged<bool> onHideOnHomeChanged;

  @override
  Widget build(BuildContext context) {
    final autoSweepInfo = this.autoSweepInfo;
    final hideOnHomeSubtitle = canHideOnHome
        ? hideOnHomeInfo
        : hideOnHomeUnavailableInfo;
    return Column(
      children: [
        SwitchListTile(
          key: autoSweepSwitchKey,
          value: autoSweepEnabled,
          onChanged: saving ? null : onAutoSweepChanged,
          title: Text(autoSweepLabel),
          subtitle: autoSweepInfo == null ? null : Text(autoSweepInfo),
        ),
        SwitchListTile(
          key: hideOnHomeSwitchKey,
          value: hideOnHome,
          onChanged: saving || !(canHideOnHome || hideOnHome)
              ? null
              : onHideOnHomeChanged,
          title: Text(hideOnHomeLabel),
          subtitle: hideOnHomeSubtitle == null
              ? null
              : Text(hideOnHomeSubtitle),
        ),
      ],
    );
  }
}
