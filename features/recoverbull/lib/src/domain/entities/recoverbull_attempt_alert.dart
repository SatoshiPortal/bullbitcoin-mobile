import 'key_server_attempts.dart';

enum RecoverBullAttemptAlertKind {
  suspiciousActivity,
  targetedLockout,
  servicePressure,
  identifierSaturation,
  unavailable,
}

final class RecoverBullAttemptAlert {
  final RecoverBullAttemptAlertKind kind;
  final String? backupReference;

  /// Opaque complete backup digest used to correlate related event alerts.
  /// Never display or log this value.
  final String correlationId;

  /// Stable identity of this particular event, used for deduplication and
  /// acknowledgement. This is not the backup correlation identifier.
  final String identity;
  final int? observedTotal;
  final int? expectedTotal;
  final DateTime? windowStartedAt;

  RecoverBullAttemptAlert(this.kind)
    : backupReference = null,
      correlationId = kind.name,
      identity = kind.name,
      observedTotal = null,
      expectedTotal = null,
      windowStartedAt = null;

  const RecoverBullAttemptAlert._(
    this.kind,
    this.correlationId,
    this.identity, {
    this.backupReference,
    this.observedTotal,
    this.expectedTotal,
    this.windowStartedAt,
  });

  factory RecoverBullAttemptAlert.suspiciousActivity({
    required String backupReference,
    required String correlationId,
    required int observedTotal,
    required int expectedTotal,
    required DateTime windowStartedAt,
  }) => RecoverBullAttemptAlert._(
    RecoverBullAttemptAlertKind.suspiciousActivity,
    correlationId,
    's:$correlationId:${attemptWindowIdentity(windowStartedAt)}',
    backupReference: backupReference,
    observedTotal: observedTotal,
    expectedTotal: expectedTotal,
    windowStartedAt: windowStartedAt,
  );

  factory RecoverBullAttemptAlert.servicePressure({
    bool identifierSaturation = false,
  }) => RecoverBullAttemptAlert._(
    identifierSaturation
        ? RecoverBullAttemptAlertKind.identifierSaturation
        : RecoverBullAttemptAlertKind.servicePressure,
    identifierSaturation
        ? 'service:identifierSaturation'
        : 'service:serviceBusy',
    identifierSaturation ? 'p:identifierSaturation' : 'p:serviceBusy',
  );

  factory RecoverBullAttemptAlert.unavailable() =>
      const RecoverBullAttemptAlert._(
        RecoverBullAttemptAlertKind.unavailable,
        'unavailable',
        'u',
      );

  factory RecoverBullAttemptAlert.targetedLockout({
    required String backupReference,
    required String correlationId,
  }) => RecoverBullAttemptAlert._(
    RecoverBullAttemptAlertKind.targetedLockout,
    correlationId,
    'l:$correlationId',
    backupReference: backupReference,
  );
}
