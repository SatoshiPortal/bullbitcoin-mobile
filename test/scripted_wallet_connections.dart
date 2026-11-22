import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

/// Supplies the outcome of the selected servers without opening a connection.
final class ScriptedWalletConnections implements WalletConnectionPort {
  final networks = <Network>[];
  final retried = <SyncFailure>[];
  Result<Object, SyncFailure> Function() reply = () =>
      throw StateError('Unexpected server access');

  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) async {
    networks.add(network);
    switch (reply()) {
      case Ok(value: final T value):
        return Ok(value);
      case Err(:final failure):
        if (mayRetry(failure)) retried.add(failure);
        return Err(failure);
      case Ok():
        throw StateError('Unexpected server result type');
    }
  }
}
