import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';

/// Formats [sats] in the user's chosen unit. Shared by every sweep widget so a
/// single amount never renders two ways on the same screen.
///
/// Deliberately ignores the hide-amounts setting: a sweep is a spending flow,
/// like `send`, which also shows amounts in clear. Masking the balance here
/// would leave the user allocating against a number they cannot see, and
/// masking the review step would mean signing blind. The Coins *list* masks
/// amounts because it is a passive balance view — a different job.
String formatSweepAmount(BigInt sats, BitcoinUnit unit) {
  return unit == BitcoinUnit.btc
      ? FormatAmount.btc(ConvertAmount.satsToBtc(sats.toInt()))
      : FormatAmount.sats(sats.toInt());
}
