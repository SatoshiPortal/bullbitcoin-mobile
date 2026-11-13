import 'package:primitives/primitives.dart';
import '../recoverbull_failure.dart';
import '../recoverbull_legacy_settings_port.dart';
import '../repositories/backup_metadata_repository.dart';

final class ImportBackupSettingsUsecase {
  final BackupMetadataRepository _metadata;
  final RecoverBullLegacySettingsPort _legacy;
  const ImportBackupSettingsUsecase(this._metadata, this._legacy);

  Future<Result<void, RecoverBullFailure>> execute() async =>
      switch (await _legacy.read()) {
        Err(:final failure) => Err(failure),
        Ok(:final value) => _metadata.importLegacy(value),
      };
}
