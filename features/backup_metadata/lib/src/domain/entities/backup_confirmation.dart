import 'package:backup_storage/backup_storage.dart' show BackupDestination;

import '../ports/backup_secrets_port.dart';

/// Exactly what the user is asked to confirm: the destination and the account
/// that were granted, the generation of the selection they replace and the
/// session it was shown in. Confirming it is valid only if all of it still
/// holds when the selection is written.
final class BackupConfirmation {
  final BackupDestination destination;

  /// As the storage names the account; shown on the confirmation only.
  final String account;
  final int generation;
  final BackupSessionRef session;

  /// Single-use: replaced by the next staging, dropped by a decline, spent by
  /// the confirmation.
  final String token;

  /// Exactly the groups shown.
  final Set<String> groups;

  const BackupConfirmation({
    required this.destination,
    required this.account,
    required this.generation,
    required this.session,
    required this.token,
    required this.groups,
  });
}
