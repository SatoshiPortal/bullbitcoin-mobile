import 'package:primitives/primitives.dart';

import '../entities/backup_settings.dart';
import '../recoverbull_failure.dart';
import '../repositories/backup_metadata_repository.dart';
import '../repositories/key_server_repository.dart';
import '../repositories/key_server_session_repository.dart';

/// Consent is checked before touching Tor and again after asynchronous opening.
/// The caller owns the returned session until its flow ends.
final class OpenKeyServerUsecase {
  final BackupMetadataRepository _metadata;
  final KeyServerSessionRepository _sessions;

  const OpenKeyServerUsecase(this._metadata, this._sessions);

  Future<Result<KeyServerRepository, RecoverBullFailure>> execute({
    required BackupSettings expected,
    bool monitoring = false,
    bool restartEmbedded = false,
  }) async {
    final allowed = await _allowed(expected, monitoring);
    if (!allowed) return const Err(VaultContextChangedFailure());
    final opened = await _sessions.open(
      expected.server,
      restartEmbedded: restartEmbedded,
    );
    switch (opened) {
      case Err():
        return opened;
      case Ok(:final value):
        if (!await _allowed(expected, monitoring)) {
          await value.close();
          return const Err(VaultContextChangedFailure());
        }
        return opened;
    }
  }

  Future<bool> _allowed(BackupSettings expected, bool monitoring) async =>
      switch (await _metadata.settings()) {
        Ok(:final value) =>
          value.permissionGranted &&
              (!monitoring || value.monitoringEnabled) &&
              value.server == expected.server &&
              value.generation == expected.generation,
        Err() => false,
      };
}
