import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:flutter/widgets.dart';

/// Short marker labels for coin sources shown on badges: SP, SW (segwit),
/// TR (taproot).
extension CoinSourceLabel on SpCoinSource {
  String shortLabel(BuildContext context) => switch (this) {
    SpCoinSource.sp => context.loc.spCoinSourceSp,
    SpCoinSource.segwit => context.loc.spCoinSourceSegwit,
    SpCoinSource.taproot => context.loc.spCoinSourceTaproot,
    SpCoinSource.other => context.loc.spCoinSourceOther,
  };

  /// Badge color for a coin source. `other` falls back to a muted color so an
  /// unexpected variant renders gracefully instead of crashing the page.
  Color sourceColor(BuildContext context) => switch (this) {
    SpCoinSource.sp => context.appColors.success,
    SpCoinSource.segwit => context.appColors.primary,
    SpCoinSource.taproot => context.appColors.tertiary,
    SpCoinSource.other => context.appColors.textMuted,
  };
}
