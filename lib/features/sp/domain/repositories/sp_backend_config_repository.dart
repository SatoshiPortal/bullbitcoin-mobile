import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';

/// Persists the [SpBackendConfig] so the live session can be reconstructed via
/// `createFromMnemonic` on every load, instead of relying on `SpAccount.load`
/// reading a config file the FFI create path never writes.
abstract interface class SpBackendConfigRepository {
  /// Synchronous view of "the SP wallet is set up", for the GoRouter redirect
  /// that gates SP routes and cannot await.
  ///
  /// `CheckSpWalletSetupUsecase` stays the authority; this is the cached view
  /// of its last answer, refreshed on every check and written directly by
  /// create and revoke so a redirect in the same turn as the navigation that
  /// follows already sees the new value. Kept here rather than in a separate
  /// holder so one object owns the value.
  bool get isSetUpNow;

  /// Update the cached view. Called by the setup check, create, and revoke.
  void setIsSetUpNow({required bool isSetUp});

  /// Persist the config. This is a try/catch boundary; a storage write failure
  /// is `Err`, never a throw.
  @useResult
  Future<Result<void, SpFailure>> save(SpBackendConfig config);

  /// Read the stored config. `Ok(null)` when nothing is stored; `Err` with
  /// [SpConfigInvalid] when the stored JSON is corrupt or names an unknown
  /// network, or [SpUnexpected] when the storage read itself failed (a locked
  /// keystore). This is a try/catch boundary; callers never see a raw
  /// exception.
  @useResult
  Future<Result<SpBackendConfig?, SpFailure>> fetch();

  /// Drop the stored config. This is a try/catch boundary; a storage delete
  /// failure is `Err`, never a throw.
  @useResult
  Future<Result<void, SpFailure>> delete();
}

extension SpBackendConfigRepositoryX on SpBackendConfigRepository {
  /// The stored config, treating a corrupt or unknown-network config as absent:
  /// `Ok(null)` for both "nothing stored" and [SpConfigInvalid], since setup
  /// overwrites a corrupt config anyway.
  ///
  /// A storage read failure stays `Err`. A keystore that cannot be read is not
  /// the same as "no wallet", and folding it to null lets a second setup run
  /// over a live one.
  @useResult
  Future<Result<SpBackendConfig?, SpFailure>> fetchOrNull() async =>
      switch (await fetch()) {
        Ok(:final value) => Ok(value),
        Err(failure: SpConfigInvalid()) => const Ok(null),
        Err(:final failure) => Err(failure),
      };
}
