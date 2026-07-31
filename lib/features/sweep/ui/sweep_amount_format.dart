import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';

/// Formats [sats] in the user's chosen unit. Shared by every sweep widget so a
/// single amount never renders two ways on the same screen.
String formatSweepAmount(BigInt sats, BitcoinUnit unit, {bool hidden = false}) {
  if (hidden) return '•••• ${unit.code}';
  return unit == BitcoinUnit.btc
      ? FormatAmount.btc(ConvertAmount.satsToBtc(sats.toInt()))
      : FormatAmount.sats(sats.toInt());
}

/// Formats a satoshi value for the editable amount field without routing it
/// through a binary floating-point number.
String formatSweepAmountInput(BigInt? sats, BitcoinUnit unit) {
  if (sats == null) return '';
  if (unit == BitcoinUnit.sats) return sats.toString();

  final padded = sats.toString().padLeft(9, '0');
  final whole = padded.substring(0, padded.length - 8);
  final fraction = padded
      .substring(padded.length - 8)
      .replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? whole : '$whole.$fraction';
}

/// Parses the editable amount exactly. Both `.` and `,` are accepted as the
/// decimal separator, but Bitcoin amounts may never exceed eight decimals.
BigInt? parseSweepAmountInput(String text, BitcoinUnit unit) {
  final normalized = text.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;

  if (unit == BitcoinUnit.sats) {
    if (!RegExp(r'^\d+$').hasMatch(normalized)) return null;
    final sats = BigInt.tryParse(normalized);
    return sats != null && sats > BigInt.zero ? sats : null;
  }

  if (!RegExp(r'^\d+(?:\.\d{0,8})?$').hasMatch(normalized)) return null;
  final parts = normalized.split('.');
  final fraction = parts.length == 2 ? parts[1] : '';
  final sats = BigInt.tryParse('${parts.first}${fraction.padRight(8, '0')}');
  return sats != null && sats > BigInt.zero ? sats : null;
}
