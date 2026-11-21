import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/data/datasources/sp_account_files_datasource.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_account_files_port.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';

/// Secondary adapter for the Silent Payments account directory. One external
/// system (the filesystem) behind one datasource, and the try/catch boundary
/// that turns a thrown `dart:io` error into a typed [SpFailure].
///
/// Kept apart from the session adapter on purpose: none of this touches the
/// FFI, and the sequencing revoke and recovery need is orchestration that
/// belongs in a use case.
///
/// Shares its datasource instance with the session adapter, which still needs
/// the data dir and the stale-lock sweep when it opens an account.
class SpAccountFilesRepository implements SpAccountFilesPort {
  final SpAccountFilesDatasource _files;

  SpAccountFilesRepository({required this._files});

  @override
  Future<Result<bool, SpFailure>> accountDirExists() =>
      _guard(_files.accountDirExists, 'account dir lookup');

  @override
  Future<Result<void, SpFailure>> writeRevokedSentinel({
    bool skipIfPresent = false,
  }) => _guard(
    () => _files.writeRevokedSentinel(skipIfPresent: skipIfPresent),
    'revoke sentinel write',
  );

  @override
  Future<Result<void, SpFailure>> deleteAccountDir() =>
      _guard(_files.deleteAccountDir, 'account dir delete');

  @override
  Future<Result<bool, SpFailure>> adoptNewestBackup() =>
      _guard(_files.adoptNewestBackup, 'backup adopt');

  @override
  Future<Result<void, SpFailure>> deleteOrphanBackups() =>
      _guard(_files.deleteOrphanBackups, 'orphan backup delete');

  @override
  Future<Result<bool, SpFailure>> hasRevokedSentinel() =>
      _guard(_files.hasRevokedSentinel, 'sentinel check');

  /// The one try/catch boundary: every datasource call throws on failure and
  /// comes back as a typed failure carrying only a log message.
  Future<Result<T, SpFailure>> _guard<T>(
    Future<T> Function() body,
    String what,
  ) async {
    try {
      return Ok(await body());
    } catch (e) {
      return Err(SpUnexpected('SP $what failed: $e'));
    }
  }
}
