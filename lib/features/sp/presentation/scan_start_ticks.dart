import 'package:bb_mobile/generated/l10n/localization.dart';

/// One labelled stop on the scan-start ruler.
typedef ScanStartTick = ({String label, int height});

/// The time unit a scan-start ruler stop is expressed in.
enum _TickUnit { year, month, week }

/// Approximate days per unit (365-day years, 30-day months), used to map a
/// stop's offset to a block height.
int _unitDays(_TickUnit unit) => switch (unit) {
  _TickUnit.year => 365,
  _TickUnit.month => 30,
  _TickUnit.week => 7,
};

/// Builds the ruler stops for the first-scan start chooser, ordered leftmost
/// (oldest) to rightmost (newest): the earliest scannable height, then 1 year,
/// 6 down to 1 months, then 3 down to 1 weeks ago. Each time offset is mapped
/// to a height with `tip - days * blocksPerDay`. Stops that fall at or below
/// `minBirthday` (other than the earliest stop) or above `tip` are dropped, and
/// duplicate heights are removed, so on a short chain only the meaningful stops
/// remain.
List<ScanStartTick> scanStartTicks({
  required AppLocalizations loc,
  required int tip,
  required int minBirthday,
  required int blocksPerDay,
}) {
  const offsets = <({_TickUnit unit, int count})>[
    (unit: _TickUnit.year, count: 1),
    (unit: _TickUnit.month, count: 6),
    (unit: _TickUnit.month, count: 5),
    (unit: _TickUnit.month, count: 4),
    (unit: _TickUnit.month, count: 3),
    (unit: _TickUnit.month, count: 2),
    (unit: _TickUnit.month, count: 1),
    (unit: _TickUnit.week, count: 3),
    (unit: _TickUnit.week, count: 2),
    (unit: _TickUnit.week, count: 1),
  ];

  final ticks = <ScanStartTick>[
    (label: loc.spScanTickEarliest, height: minBirthday),
  ];
  final seen = <int>{minBirthday};
  for (final o in offsets) {
    final height = tip - o.count * _unitDays(o.unit) * blocksPerDay;
    if (height <= minBirthday || height > tip || seen.contains(height)) {
      continue;
    }
    seen.add(height);
    ticks.add((label: _tickLabel(loc, o.unit, o.count), height: height));
  }
  return ticks;
}

String _tickLabel(AppLocalizations loc, _TickUnit unit, int count) =>
    switch (unit) {
      _TickUnit.year => loc.spDurationYears(count),
      _TickUnit.month => loc.spDurationMonths(count),
      _TickUnit.week => loc.spDurationWeeks(count),
    };

/// Approximate a block count as a human-readable duration, e.g. "1 year
/// 10 months", "2 days 4 hours", "3 hours". Shows the two most-significant
/// non-zero units (years/months/days/hours); under an hour returns "less than
/// an hour". Approximate (30-day months, 365-day years) and only indicative on
/// test networks where blocks are mined on demand.
String blocksToApproxDuration(
  AppLocalizations loc,
  int blocks, {
  required int blocksPerDay,
}) {
  // Approximate calendar buckets: 365-day years, 30-day months.
  const hoursPerYear = 365 * 24;
  const hoursPerMonth = 30 * 24;
  var hours = blocks * 24 ~/ blocksPerDay;
  final years = hours ~/ hoursPerYear;
  hours %= hoursPerYear;
  final months = hours ~/ hoursPerMonth;
  hours %= hoursPerMonth;
  final days = hours ~/ 24;
  hours %= 24;

  final units = <String>[
    if (years > 0) loc.spDurationYears(years),
    if (months > 0) loc.spDurationMonths(months),
    if (days > 0) loc.spDurationDays(days),
    if (hours > 0) loc.spDurationHours(hours),
  ];
  if (units.isEmpty) return loc.spDurationLessThanHour;
  return units.take(2).join(' ');
}
