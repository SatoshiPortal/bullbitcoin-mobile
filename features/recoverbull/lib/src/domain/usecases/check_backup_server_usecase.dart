import 'package:primitives/primitives.dart';
import '../recoverbull_failure.dart';
import 'open_key_server_usecase.dart';
import '../repositories/backup_metadata_repository.dart';
import '../entities/backup_settings.dart';

/// An explicit status-screen request owns and releases its own session.
final class CheckBackupServerUsecase {
  final OpenKeyServerUsecase? _open;
  final BackupMetadataRepository? _metadata;
  final RecoverBullFailure unavailable;
  const CheckBackupServerUsecase(this._open, this._metadata, this.unavailable);

  Future<Result<bool, RecoverBullFailure>> execute() async {
    final open = _open;
    final metadata = _metadata;
    if (open == null || metadata == null) return Err(unavailable);
    final BackupSettings settings;
    switch (await metadata.settings()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        settings = value;
    }
    switch (await open.execute(expected: settings)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        try {
          return (await value.probe()).map((_) => true);
        } finally {
          await value.close();
        }
    }
  }
}
