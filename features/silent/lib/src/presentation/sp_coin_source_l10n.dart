import 'package:bull_ui/bull_ui.dart' show BullThemeX;
import 'package:silent/src/presentation/silent_l10n.dart';
import 'package:silent/src/domain/entities/sp_coin.dart';
import 'package:flutter/widgets.dart';

/// Short marker labels for coin sources shown on badges: SP, SW (segwit),
/// TR (taproot).
extension SpCoinSourceL10n on SpCoinSource {
  String shortLabel(BuildContext context) => switch (this) {
    SpCoinSource.sp => context.silentLoc.silentCoinSourceSp,
    SpCoinSource.segwit => context.silentLoc.silentCoinSourceSegwit,
    SpCoinSource.taproot => context.silentLoc.silentCoinSourceTaproot,
    SpCoinSource.other => context.silentLoc.silentCoinSourceOther,
  };

  /// Badge color for a coin source. `other` falls back to a muted color so an
  /// unexpected variant renders gracefully instead of crashing the page.
  Color sourceColor(BuildContext context) => switch (this) {
    SpCoinSource.sp => context.bull.success,
    SpCoinSource.segwit => context.bull.primary,
    SpCoinSource.taproot => context.bull.tertiary,
    SpCoinSource.other => context.bull.textMuted,
  };
}
