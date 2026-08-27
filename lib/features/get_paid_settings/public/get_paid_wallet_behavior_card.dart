import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/get_paid_wallet_behavior.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';

/// The reserved product wallet's two behavior switches — auto-sweep and
/// hide-on-home — as one card.
///
/// Every Get Paid surface shows exactly this card, whether inside the Advanced
/// Settings sheet or inline on a screen whose online product is unavailable, so
/// the labels, the ordering and the rule coupling the two switches are stated in
/// one place. It is presentational: the caller owns the writes.
///
/// It lives in `public/` because it is typed on this feature's published
/// [GetPaidWalletBehavior] and the product features render it directly.
class GetPaidWalletBehaviorCard extends StatelessWidget {
  const GetPaidWalletBehaviorCard({
    super.key,
    required this.behavior,
    required this.saving,
    required this.onAutoSweepChanged,
    required this.onHideOnHomeChanged,
  });

  final GetPaidWalletBehavior behavior;

  /// True while a behavior write is in flight — both switches are inert.
  final bool saving;

  final ValueChanged<bool> onAutoSweepChanged;
  final ValueChanged<bool> onHideOnHomeChanged;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Card(
      margin: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          ListTile(title: Text(loc.getPaidWalletSettingsSectionTitle)),
          BullWalletBehaviorSwitches(
            autoSweepSwitchKey: const Key('get_paid_auto_sweep_switch'),
            hideOnHomeSwitchKey: const Key('get_paid_hide_on_home_switch'),
            hideOnHome: behavior.hideOnHome,
            autoSweepEnabled: behavior.autoSweepEnabled,
            canHideOnHome: behavior.canHideOnHome,
            saving: saving,
            autoSweepLabel: loc.getPaidWalletAutoSweepLabel,
            autoSweepInfo: loc.getPaidWalletAutoSweepInfo,
            hideOnHomeLabel: loc.getPaidWalletHideOnHomeLabel,
            hideOnHomeInfo: loc.getPaidWalletHideOnHomeInfo,
            hideOnHomeUnavailableInfo:
                loc.getPaidWalletHideOnHomeNeedsAutoSweep,
            onAutoSweepChanged: onAutoSweepChanged,
            onHideOnHomeChanged: onHideOnHomeChanged,
          ),
        ],
      ),
    );
  }
}
