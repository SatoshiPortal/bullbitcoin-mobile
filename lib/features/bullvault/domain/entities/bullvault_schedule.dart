import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';

final class BullVaultSchedule {
  static const minDelayYears = 1;
  static const maxDelayYears = 10;

  final int coldYears;
  final int recoveryYears;
  final int inheritanceYears;

  const BullVaultSchedule({
    this.coldYears = 2,
    this.recoveryYears = 3,
    this.inheritanceYears = 5,
  });

  static const standardWithInheritance = BullVaultSchedule(
    coldYears: 3,
    recoveryYears: 2,
    inheritanceYears: 5,
  );

  static const standardWithoutInheritance = BullVaultSchedule();

  static const extraWithInheritance = BullVaultSchedule(
    recoveryYears: 2,
    inheritanceYears: 5,
  );

  static const extraWithoutInheritance = BullVaultSchedule(
    coldYears: 3,
    recoveryYears: 5,
  );

  static BullVaultSchedule defaultsFor({
    required BullVaultProtection protection,
    required bool includesInheritance,
  }) => switch ((protection, includesInheritance)) {
    (BullVaultProtection.standard, false) => standardWithoutInheritance,
    (BullVaultProtection.standard, true) => standardWithInheritance,
    (BullVaultProtection.extra, false) => extraWithoutInheritance,
    (BullVaultProtection.extra, true) => extraWithInheritance,
  };

  DateTime coldActivationDate(DateTime referenceTime) =>
      _addCalendarYears(referenceTime, coldYears);

  DateTime recoveryActivationDate(DateTime referenceTime) =>
      _addCalendarYears(referenceTime, recoveryYears);

  DateTime inheritanceActivationDate(DateTime referenceTime) =>
      _addCalendarYears(referenceTime, inheritanceYears);

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
        _isInRange(coldYears) &&
        _isInRange(recoveryYears) &&
        _isInRange(inheritanceYears);
    if (!valuesAreInRange) return false;
    return switch ((protection, includesInheritance)) {
      (BullVaultProtection.standard, false) => coldYears < recoveryYears,
      (BullVaultProtection.standard, true) =>
        recoveryYears < coldYears && coldYears < inheritanceYears,
      (BullVaultProtection.extra, false) => coldYears < recoveryYears,
      (BullVaultProtection.extra, true) => recoveryYears < inheritanceYears,
    };
  }

  BullVaultSchedule copyWith({
    int? coldYears,
    int? recoveryYears,
    int? inheritanceYears,
  }) => BullVaultSchedule(
    coldYears: coldYears ?? this.coldYears,
    recoveryYears: recoveryYears ?? this.recoveryYears,
    inheritanceYears: inheritanceYears ?? this.inheritanceYears,
  );

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

  static bool _isInRange(int years) =>
      years >= minDelayYears && years <= maxDelayYears;
}
