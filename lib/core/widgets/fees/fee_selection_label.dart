import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';

/// Value shown on the "Fee Priority" row of the exchange confirmation screens
/// (sell, pay) for the committed selection. Presets read as their tier name; a
/// custom fee reads as the value that was typed, because "Custom Fee" on its
/// own hides the only number that tells the tiers apart.
///
/// [fastestLabel] comes from the caller: each flow ships its own translated
/// "Fastest" string, while the remaining tiers have no per-flow copy and share
/// the send keys.
String feeSelectionRowLabel(
  BuildContext context, {
  required FeeSelection selection,
  required NetworkFee? customFee,
  required String fastestLabel,
}) => switch (selection) {
  FeeSelection.fastest => fastestLabel,
  FeeSelection.economic => context.loc.sendEconomyFee,
  FeeSelection.slow => context.loc.feePrioritySlow,
  FeeSelection.custom => switch (customFee) {
    RelativeFee(:final satPerKwu) =>
      '${_formattedRate(satPerKwu / 250.0)} ${context.loc.sendSatsPerVB}',
    AbsoluteFee(:final sats) =>
      '${FormatAmount.sats(sats)} ${context.loc.sendSats}',
    // Custom is selected but nothing has been typed yet — only reachable
    // while the modal is open, since dismissal rolls an empty field back.
    null => context.loc.sendCustomFee,
  },
};

/// Whole rates lose the decimals: "3 sats/vB" rather than "3.00 sats/vB".
String _formattedRate(double satPerVbyte) =>
    satPerVbyte == satPerVbyte.roundToDouble()
    ? satPerVbyte.toStringAsFixed(0)
    : satPerVbyte.toStringAsFixed(2);
