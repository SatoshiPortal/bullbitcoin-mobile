import '../repositories/recoverbull_repository.dart';
import '../entities/encrypted_vault.dart';
import '../recoverbull_failure.dart';
import './ensure_recoverbull_tor_session_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import '../recoverbull_tor_route.dart';

/// Stores a backup key on the server with password protection
class StoreVaultKeyIntoServerUsecase {
  final LogSink log;
  final RecoverBullRepository _recoverBullRepository;
  final EnsureRecoverBullTorSessionUsecase _ensureTorSessionUsecase;
  StoreVaultKeyIntoServerUsecase({
    required RecoverBullRepository repository,
    required EnsureRecoverBullTorSessionUsecase ensureTor,
    required this.log,
  }) : _recoverBullRepository = repository,
       _ensureTorSessionUsecase = ensureTor;

  Future<Result<Null, RecoverBullFailure>> execute({
    required String password,
    required EncryptedVault vault,
    required String vaultKey,
    RecoverBullTorRoute? route,
  }) async {
    if (route != null) {
      return _store(password, vault, vaultKey, route, ownsRoute: false);
    }
    final session = await _ensureTorSessionUsecase.execute();
    return switch (session) {
      Ok(:final value) => _store(
        password,
        vault,
        vaultKey,
        value,
        ownsRoute: true,
      ),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<Null, RecoverBullFailure>> _store(
    String password,
    EncryptedVault vault,
    String vaultKey,
    RecoverBullTorRoute session, {
    required bool ownsRoute,
  }) async {
    try {
      final result = await _recoverBullRepository.storeVaultKey(
        vault.id,
        password,
        vault.salt,
        vaultKey,
        session,
      );
      return result;
    } finally {
      // A throw here would escape after the key was already stored, leaving the
      // flow half-completed with no typed failure for the caller to act on.
      try {
        if (ownsRoute) await session.close();
      } catch (e, st) {
        log.warning(
          'closing the RecoverBull Tor session failed',
          error: e,
          trace: st,
        );
      }
    }
  }
}
