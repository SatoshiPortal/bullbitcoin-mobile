import 'package:bull_logger/bull_logger.dart';

/// Logs the server values this build does not know: a status, a frequency,
/// a type. Each (kind, value) pair is logged once for the life of the app, so
/// a server that adds a value does not flood the log on every poll.
abstract final class UnknownServerValues {
  static const _missing = '<missing>';
  static const _maxLength = 40;

  static final _reported = <(String, String)>{};

  /// Reports [raw] as an unknown [kind] (e.g. `order status`); a null [raw]
  /// is a missing value. Returns whether this call logged it.
  static bool report(String kind, String? raw) {
    final value = raw == null
        ? _missing
        : raw.length > _maxLength
        ? '${raw.substring(0, _maxLength)}…'
        : raw;
    if (!_reported.add((kind, value))) return false;
    log.warning('Unknown $kind from the exchange: $value');
    return true;
  }
}

/// Maps a server string to one of [values], or to [unknown] when no other
/// value has [wire] equal to [raw]. An unknown or missing [raw] is reported
/// through [UnknownServerValues] as a [kind]. [unknown] itself never matches,
/// so a server that sends the literal name of the fallback is still logged.
T serverValue<T extends Enum>(
  String kind,
  String? raw, {
  required List<T> values,
  required String Function(T value) wire,
  required T unknown,
}) {
  for (final value in values) {
    if (value != unknown && wire(value) == raw) return value;
  }
  UnknownServerValues.report(kind, raw);
  return unknown;
}
