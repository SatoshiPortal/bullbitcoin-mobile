import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';

enum BullVaultScheduleUnit { years, hours }

final class BullVaultSchedule {
  static const minDelay = 1;
  static const maxDelay = 10;

  final int coldDelay;
  final int recoveryDelay;
  final int inheritanceDelay;
  final BullVaultScheduleUnit unit;

  const BullVaultSchedule({
    this.coldDelay = 2,
    this.recoveryDelay = 3,
    this.inheritanceDelay = 5,
    this.unit = BullVaultScheduleUnit.years,
  });

  static const standardWithInheritance = BullVaultSchedule(
    coldDelay: 3,
    recoveryDelay: 2,
    inheritanceDelay: 5,
  );

  static const standardWithoutInheritance = BullVaultSchedule();

  static const extraWithInheritance = BullVaultSchedule(
    recoveryDelay: 2,
    inheritanceDelay: 5,
  );

  static const extraWithoutInheritance = BullVaultSchedule(
    coldDelay: 3,
    recoveryDelay: 5,
  );

  static BullVaultSchedule defaultsFor({
    required BullVaultProtection protection,
    required bool includesInheritance,
    BullVaultScheduleUnit unit = BullVaultScheduleUnit.years,
  }) {
    final defaults = switch ((protection, includesInheritance)) {
      (BullVaultProtection.standard, false) => standardWithoutInheritance,
      (BullVaultProtection.standard, true) => standardWithInheritance,
      (BullVaultProtection.extra, false) => extraWithoutInheritance,
      (BullVaultProtection.extra, true) => extraWithInheritance,
    };
    return defaults.copyWith(unit: unit);
  }

  bool get isPractice => unit == BullVaultScheduleUnit.hours;

  bool isDefaultFor({
    required BullVaultProtection protection,
    required bool includesInheritance,
  }) {
    final defaults = defaultsFor(
      protection: protection,
      includesInheritance: includesInheritance,
    );
    return coldDelay == defaults.coldDelay &&
        recoveryDelay == defaults.recoveryDelay &&
        inheritanceDelay == defaults.inheritanceDelay;
  }

  DateTime coldActivationDate(DateTime referenceTime) =>
      _activationDate(referenceTime, coldDelay);

  DateTime recoveryActivationDate(DateTime referenceTime) =>
      _activationDate(referenceTime, recoveryDelay);

  DateTime inheritanceActivationDate(DateTime referenceTime) =>
      _activationDate(referenceTime, inheritanceDelay);

  int coldActivationTimestamp(DateTime referenceTime) =>
      coldActivationDate(referenceTime).millisecondsSinceEpoch ~/ 1000;

  int recoveryActivationTimestamp(DateTime referenceTime) =>
      recoveryActivationDate(referenceTime).millisecondsSinceEpoch ~/ 1000;

  int inheritanceActivationTimestamp(DateTime referenceTime) =>
      inheritanceActivationDate(referenceTime).millisecondsSinceEpoch ~/ 1000;

  bool isValid({
    required BullVaultProtection protection,
    required bool includesInheritance,
  }) {
    final valuesAreInRange =
        _isInRange(coldDelay) &&
        _isInRange(recoveryDelay) &&
        _isInRange(inheritanceDelay);
    if (!valuesAreInRange) return false;
    return switch ((protection, includesInheritance)) {
      (BullVaultProtection.standard, false) => coldDelay < recoveryDelay,
      (BullVaultProtection.standard, true) =>
        recoveryDelay < coldDelay && coldDelay < inheritanceDelay,
      (BullVaultProtection.extra, false) => coldDelay < recoveryDelay,
      (BullVaultProtection.extra, true) => recoveryDelay < inheritanceDelay,
    };
  }

  BullVaultSchedule copyWith({
    int? coldDelay,
    int? recoveryDelay,
    int? inheritanceDelay,
    BullVaultScheduleUnit? unit,
  }) => BullVaultSchedule(
    coldDelay: coldDelay ?? this.coldDelay,
    recoveryDelay: recoveryDelay ?? this.recoveryDelay,
    inheritanceDelay: inheritanceDelay ?? this.inheritanceDelay,
    unit: unit ?? this.unit,
  );

  DateTime _activationDate(DateTime referenceTime, int delay) => switch (unit) {
    BullVaultScheduleUnit.years => _addCalendarYears(referenceTime, delay),
    BullVaultScheduleUnit.hours => referenceTime.toUtc().add(
      Duration(hours: delay),
    ),
  };

  static DateTime _addCalendarYears(DateTime referenceTime, int years) {
    final reference = referenceTime.toUtc();
    final targetYear = reference.year + years;
    final lastDay = DateTime.utc(targetYear, reference.month + 1, 0).day;
    final targetDay = reference.day > lastDay ? lastDay : reference.day;
    return DateTime.utc(
      targetYear,
      reference.month,
      targetDay,
      reference.hour,
      reference.minute,
      reference.second,
    );
  }

  static bool _isInRange(int delay) => delay >= minDelay && delay <= maxDelay;
}
