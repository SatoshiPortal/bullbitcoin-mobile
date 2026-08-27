import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/get_paid_wallet_behavior.dart';
import 'package:bb_mobile/features/get_paid_settings/public/get_paid_wallet_behavior_card.dart';
import 'package:flutter/material.dart';

/// The shared Advanced Settings sheet for every Get Paid product (Lightning
/// Address, Donation Page, POS). It renders the SAME three controls — turn
/// on/off, Hide on Home, Auto-Sweep — driven purely by values + callbacks, so
/// each product wires its own turn-on/off action and wallet-behavior writes
/// without any product-specific branching inside this widget.
///
/// It lives in `public/` because it is the UI face of this feature's
/// wallet-behavior contract and the product features render it directly — the
/// same shape as `fiat_settlement/public/fiat_settlement_entry_tile.dart`.
class GetPaidAdvancedSettingsSheet extends StatelessWidget {
  const GetPaidAdvancedSettingsSheet({
    super.key,
    required this.onlineTitle,
    required this.onlineSubtitle,
    required this.online,
    required this.onlineSaving,
    required this.onlineSavingLabel,
    required this.onOnlineChanged,
    this.onlineSwitchKey,
    required this.walletBehavior,
    required this.walletBehaviorSaving,
    required this.onAutoSweepChanged,
    required this.onHideOnHomeChanged,
  });

  /// The turn-on/off control — an injected product action, NOT a wallet
  /// behavior. Title/subtitle are resolved by the caller for the current state.
  final String onlineTitle;
  final String onlineSubtitle;
  final bool online;
  final bool onlineSaving;
  final String onlineSavingLabel;
  final ValueChanged<bool> onOnlineChanged;
  final Key? onlineSwitchKey;

  /// The reserved product wallet's behavior (null → wallet missing, controls
  /// hidden). Auto-sweep + Hide-on-Home are wallet behaviors keyed by wallet id.
  final GetPaidWalletBehavior? walletBehavior;
  final bool walletBehaviorSaving;
  final ValueChanged<bool> onAutoSweepChanged;
  final ValueChanged<bool> onHideOnHomeChanged;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final behavior = walletBehavior;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              loc.getPaidAdvancedSettingsTitle,
              style: context.font.titleLarge,
            ),
            Card(
              margin: const EdgeInsets.only(top: 24),
              child: Column(
                children: [
                  SwitchListTile(
                    key: onlineSwitchKey,
                    value: online,
                    onChanged: onlineSaving ? null : onOnlineChanged,
                    title: Text(onlineTitle),
                    subtitle: Text(onlineSubtitle),
                  ),
                  if (onlineSaving)
                    Semantics(
                      liveRegion: true,
                      label: onlineSavingLabel,
                      child: const LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
            if (behavior != null)
              GetPaidWalletBehaviorCard(
                behavior: behavior,
                saving: walletBehaviorSaving,
                onAutoSweepChanged: onAutoSweepChanged,
                onHideOnHomeChanged: onHideOnHomeChanged,
              ),
          ],
        ),
      ),
    );
  }
}
