import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/data/datasources/sp_account_files_datasource.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_account_files_port.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';

/// Secondary adapter for the Silent Payments account directory. One external
/// system (the filesystem) behind one datasource, and the try/catch boundary
/// that turns a thrown `dart:io` error into a typed [SpFailure].
///
/// Kept apart from the session adapter on purpose: none of this touches the
/// FFI, and the sequencing a revoke or a recreate needs is orchestration that
/// belongs in a use case.
///
/// Shares its datasource instance with the session adapter, which uses the
/// data directory and identity marker. The datasource carries the recreate
/// backup across calls, so there must be exactly one of it.
class SpAccountFilesRepository implements SpAccountFilesPort {
  final SpAccountFilesDatasource _files;

  SpAccountFilesRepository({required this._files});

  @override
  Future<Result<bool, SpFailure>> accountDirExists() =>
      _guard(_files.accountDirExists, 'account dir lookup');

  @override
  Future<Result<bool, SpFailure>> hasLegacyData() =>
      _guard(_files.hasLegacyData, 'legacy data lookup');

  @override
  Future<Result<void, SpFailure>> verifyResumeBackups(SpBackendConfig config) =>
      _identityGuard(() => _files.verifyResumeBackups(config));

  @override
  Future<Result<void, SpFailure>> createAccountDir(SpBackendConfig config) =>
      _identityGuard(() => _files.createAccountDir(config));

  @override
  Future<Result<void, SpFailure>> verifyAccountIdentity(
    SpBackendConfig config,
  ) => _identityGuard(() => _files.verifyAccountIdentity(config));

  @override
  Future<Result<bool, SpFailure>> hasOrphanBackups() => _guard(
    () async =>
        await _files.hasIncompleteStaging() ||
        (await _files.findOrphanBackups()).isNotEmpty,
    'backup lookup',
  );

  @override
  Future<Result<void, SpFailure>> verifyPendingIdentity(
    SpBackendConfig config,
  ) => _identityGuard(() => _files.verifyPendingIdentity(config));

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
  Future<Result<bool, SpFailure>> backupAccountDir(SpBackendConfig config) =>
      _identityGuard(() => _files.backupAccountDir(config));

  @override
  Future<Result<bool, SpFailure>> restoreAccountDir(SpBackendConfig config) =>
      _identityGuard(() => _files.restoreAccountDir(config));

  @override
  Future<Result<void, SpFailure>> discardBackup(SpBackendConfig config) async {
    // The datasource reports a failed delete as false rather than throwing, so
    // that case needs its own failure.
    final discarded = await _identityGuard(() => _files.discardBackup(config));
    return switch (discarded) {
      Ok(value: true) => const Ok(null),
      Ok() => const Err(SpUnexpected('SP backup discard failed')),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<bool, SpFailure>> adoptNewestBackup(SpBackendConfig config) =>
      _identityGuard(() => _files.adoptNewestBackup(config));

  @override
  Future<Result<void, SpFailure>> deleteOrphanBackups(
    SpBackendConfig? config,
  ) => _identityGuard(() => _files.deleteOrphanBackups(config));

  @override
  Future<Result<bool, SpFailure>> hasRevokedSentinel() =>
      _guard(_files.hasRevokedSentinel, 'sentinel check');

  Future<Result<T, SpFailure>> _identityGuard<T>(
    Future<T> Function() body,
  ) async {
    try {
      return Ok(await body());
    } catch (_) {
      return const Err(SpRecoveryRequired());
    }
  }

  /// The one try/catch boundary: every datasource call throws on failure and
  /// comes back as a typed failure carrying only a log message.
  Future<Result<T, SpFailure>> _guard<T>(
    Future<T> Function() body,
    String what,
  ) async {
    try {
      return Ok(await body());
    } catch (_) {
      return Err(SpUnexpected('SP $what failed'));
    }
  }
}
