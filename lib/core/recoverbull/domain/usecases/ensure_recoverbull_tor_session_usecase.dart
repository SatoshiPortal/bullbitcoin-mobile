import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:tor/tor.dart';

/// Opens RecoverBull's circuit-isolated session behind its own failure boundary.
class EnsureRecoverBullTorSessionUsecase {
  final EmbeddedTor _embeddedTor;

  const EnsureRecoverBullTorSessionUsecase(this._embeddedTor);

  Future<Result<TorSession, RecoverBullCoreFailure>> execute() async {
    return switch (await _embeddedTor.ensureReady()) {
      TorReady(:final route) when route.source == TorSource.embedded =>
        _openSession(),
      TorUnavailable(:final failure) => Err(
        KeyServerUnavailableFailure(failure.logMessage),
      ),
      final state => Err(
        KeyServerUnavailableFailure(
          'Tor did not reach a terminal ready state: ${state.runtimeType}',
        ),
      ),
    };
  }

  Future<Result<TorSession, RecoverBullCoreFailure>> _openSession() async {
    try {
      return Ok(await _embeddedTor.sessions.open());
    } on TorBackendException catch (error) {
      return Err(KeyServerUnavailableFailure(error.failure.logMessage));
    } catch (error) {
      return Err(KeyServerUnavailableFailure(error.toString()));
    }
  }
}
