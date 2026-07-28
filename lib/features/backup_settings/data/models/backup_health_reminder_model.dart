import 'package:bb_mobile/features/backup_settings/domain/backup_health_reminder.dart';

class BackupHealthReminderModel {
  final int version;
  final int? lastAcknowledgedAtMillis;
  final bool crossedTenMillionSats;

  const BackupHealthReminderModel({
    required this.version,
    required this.lastAcknowledgedAtMillis,
    required this.crossedTenMillionSats,
  });

  /// Reads only the keys this record still has. Keys written by an earlier
  /// shape of the feature are ignored rather than rejected.
  factory BackupHealthReminderModel.fromJson(Map<String, dynamic> json) =>
      BackupHealthReminderModel(
        version: _requiredInt(json, 'version'),
        lastAcknowledgedAtMillis: _optionalInt(json, 'lastAcknowledgedAt'),
        crossedTenMillionSats: _optionalBool(json, 'crossedTenMillionSats'),
      );

  factory BackupHealthReminderModel.fromEntity(
    BackupHealthReminderRecord record, {
    required int version,
  }) => BackupHealthReminderModel(
    version: version,
    lastAcknowledgedAtMillis: record.lastAcknowledgedAt
        ?.toUtc()
        .millisecondsSinceEpoch,
    crossedTenMillionSats: record.crossedTenMillionSats,
  );

  Map<String, dynamic> toJson() => {
    'version': version,
    'lastAcknowledgedAt': lastAcknowledgedAtMillis,
    'crossedTenMillionSats': crossedTenMillionSats,
  };

  BackupHealthReminderRecord toEntity({required String masterFingerprint}) =>
      BackupHealthReminderRecord(
        masterFingerprint: masterFingerprint,
        lastAcknowledgedAt: _dateTimeFromMillis(lastAcknowledgedAtMillis),
        crossedTenMillionSats: crossedTenMillionSats,
      );

  DateTime? _dateTimeFromMillis(int? milliseconds) => milliseconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);

  static int _requiredInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) return value;
    throw FormatException('Invalid $key');
  }

  static int? _optionalInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null || value is int) return value as int?;
    throw FormatException('Invalid $key');
  }

  static bool _optionalBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return false;
    if (value is bool) return value;
    throw FormatException('Invalid $key');
  }
}
