import 'package:bb_mobile/features/backup_settings/domain/backup_health_reminder.dart';

class BackupHealthReminderModel {
  final int version;
  final int? lastAcknowledgedAtMillis;
  final String highestHandledBalanceTier;
  final int? pendingActionStartedAtMillis;
  final String pendingActionBalanceTier;

  const BackupHealthReminderModel({
    required this.version,
    required this.lastAcknowledgedAtMillis,
    required this.highestHandledBalanceTier,
    required this.pendingActionStartedAtMillis,
    required this.pendingActionBalanceTier,
  });

  factory BackupHealthReminderModel.fromJson(
    Map<String, dynamic> json,
  ) => BackupHealthReminderModel(
    version: _requiredInt(json, 'version'),
    lastAcknowledgedAtMillis: _optionalInt(json, 'lastAcknowledgedAt'),
    highestHandledBalanceTier: _requiredString(
      json,
      'highestHandledBalanceTier',
    ),
    pendingActionStartedAtMillis: _optionalInt(json, 'pendingActionStartedAt'),
    pendingActionBalanceTier: _requiredString(json, 'pendingActionBalanceTier'),
  );

  factory BackupHealthReminderModel.fromEntity(
    BackupHealthReminderRecord record, {
    required int version,
  }) => BackupHealthReminderModel(
    version: version,
    lastAcknowledgedAtMillis: record.lastAcknowledgedAt
        ?.toUtc()
        .millisecondsSinceEpoch,
    highestHandledBalanceTier: record.highestHandledBalanceTier.name,
    pendingActionStartedAtMillis: record.pendingActionStartedAt
        ?.toUtc()
        .millisecondsSinceEpoch,
    pendingActionBalanceTier: record.pendingActionBalanceTier.name,
  );

  Map<String, dynamic> toJson() => {
    'version': version,
    'lastAcknowledgedAt': lastAcknowledgedAtMillis,
    'highestHandledBalanceTier': highestHandledBalanceTier,
    'pendingActionStartedAt': pendingActionStartedAtMillis,
    'pendingActionBalanceTier': pendingActionBalanceTier,
  };

  BackupHealthReminderRecord toEntity({required String masterFingerprint}) =>
      BackupHealthReminderRecord(
        masterFingerprint: masterFingerprint,
        lastAcknowledgedAt: _dateTimeFromMillis(lastAcknowledgedAtMillis),
        highestHandledBalanceTier: _tierFromName(highestHandledBalanceTier),
        pendingActionStartedAt: _dateTimeFromMillis(
          pendingActionStartedAtMillis,
        ),
        pendingActionBalanceTier: _tierFromName(pendingActionBalanceTier),
      );

  DateTime? _dateTimeFromMillis(int? milliseconds) => milliseconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);

  BackupBalanceTier _tierFromName(String name) {
    for (final tier in BackupBalanceTier.values) {
      if (tier.name == name) return tier;
    }
    return BackupBalanceTier.none;
  }

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

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String) return value;
    throw FormatException('Invalid $key');
  }
}
