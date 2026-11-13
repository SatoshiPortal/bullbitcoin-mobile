import 'package:primitives/primitives.dart';

import '../entities/backup_settings.dart';
import '../recoverbull_failure.dart';
import '../recoverbull_server_url.dart';
import '../repositories/backup_metadata_repository.dart';

sealed class BackupSettingsAction {
  const BackupSettingsAction();
}

final class ReadBackupSettings extends BackupSettingsAction {
  const ReadBackupSettings();
}

final class AcceptBackupServer extends BackupSettingsAction {
  final Uri server;
  const AcceptBackupServer(this.server);
}

final class ChangeBackupServer extends BackupSettingsAction {
  final String server;
  const ChangeBackupServer(this.server);
}

final class SetBackupMonitoring extends BackupSettingsAction {
  final bool enabled;
  const SetBackupMonitoring(this.enabled);
}

final class ManageBackupSettingsUsecase {
  final BackupMetadataRepository? _metadata;
  final RecoverBullFailure unavailable;

  const ManageBackupSettingsUsecase(this._metadata, this.unavailable);

  Future<Result<BackupSettings, RecoverBullFailure>> execute(
    BackupSettingsAction action,
  ) async {
    final metadata = _metadata;
    if (metadata == null) return Err(unavailable);
    final Result<void, RecoverBullFailure> updated;
    switch (action) {
      case ReadBackupSettings():
        return metadata.settings();
      case AcceptBackupServer(:final server):
        updated = await metadata.acceptServer(server);
      case SetBackupMonitoring(:final enabled):
        updated = await metadata.setMonitoring(enabled);
      case ChangeBackupServer(:final server):
        final Uri url;
        try {
          url = validateRecoverBullServerUrl(Uri.parse(server.trim()));
        } on FormatException {
          return const Err(VaultInvalidFailure());
        } on ArgumentError {
          return const Err(VaultInvalidFailure());
        }
        updated = await metadata.changeServer(url);
    }
    return switch (updated) {
      Err(:final failure) => Err(failure),
      Ok() => metadata.settings(),
    };
  }
}
