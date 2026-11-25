import 'package:bbx_api/bbx_api.dart' as bbx;

import '../domain/entities/dca.dart';
import 'unknown_server_value.dart';

/// The one mapping between [DcaBuyFrequency] and the server's frequency
/// (`HOURLY`, `DAILY`, `WEEKLY`, `MONTHLY`). The user summary and the
/// created-DCA reply both read through [dcaFrequencyFromWire].
abstract final class DcaFrequencyWire {
  static bbx.DcaFrequency toWire(DcaBuyFrequency frequency) =>
      switch (frequency) {
        DcaBuyFrequency.hourly => bbx.DcaFrequency.hourly,
        DcaBuyFrequency.daily => bbx.DcaFrequency.daily,
        DcaBuyFrequency.weekly => bbx.DcaFrequency.weekly,
        DcaBuyFrequency.monthly => bbx.DcaFrequency.monthly,
      };
}

/// The frequency for a server value, case-insensitive. Null for a missing
/// value or one this build doesn't know; an unknown one is logged once.
/// [DcaBuyFrequency] has no unknown member because it is also the set the
/// user picks from.
DcaBuyFrequency? dcaFrequencyFromWire(String? raw) {
  if (raw == null) return null;
  final wire = raw.toUpperCase();
  for (final frequency in DcaBuyFrequency.values) {
    if (DcaFrequencyWire.toWire(frequency).value == wire) return frequency;
  }
  UnknownServerValues.report('DCA frequency', raw);
  return null;
}
