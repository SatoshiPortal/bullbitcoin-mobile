import '../entities/recoverbull_network.dart';
import '../repositories/recoverbull_repository.dart';
import './check_server_connection_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

/// Builds the first onion circuit to the key server before the user needs it.
///
/// The first request to an onion service fetches its descriptor and builds a
/// rendezvous circuit, which on a cold Tor (and more so over Snowflake) takes
/// most of a minute. Users who already have an encrypted backup will reach the
/// key server again, and their Tor is started at launch anyway, so one
/// background health check moves that cost out of the flow they open later.
/// Users without a mainnet backup never reach the key server from here.
///
/// Advisory only: it never throws, and it logs outcomes by type, never with a
/// server address or another identifier.
final class WarmKeyServerRouteUsecase {
  final LogSink log;
  final RecoverBullRepository _repository;
  final CheckServerConnectionUsecase _check;

  const WarmKeyServerRouteUsecase({
    required this._repository,
    required this._check,
    required this.log,
  });

  Future<void> execute() async {
    try {
      final status = await _repository.fetchBackupStatus(
        RecoverBullNetwork.mainnet,
      );
      if (!status.isKnown || !status.hasEncryptedBackup) return;
      // The check acquires the shared route, which waits for Tor to be ready,
      // and releases it afterwards so the flow can attach to the same route.
      final result = await _check.execute();
      switch (result) {
        case Ok(value: true):
          log.fine('recoverbull.key_server.warmup.succeeded');
        case Ok():
          log.warning('recoverbull.key_server.warmup.failed outcome=offline');
        case Err(:final failure):
          log.warning(
            'recoverbull.key_server.warmup.failed '
            'failure_type=${failure.runtimeType}',
          );
      }
    } catch (error) {
      log.warning(
        'recoverbull.key_server.warmup.failed error_type=${error.runtimeType}',
      );
    }
  }
}
