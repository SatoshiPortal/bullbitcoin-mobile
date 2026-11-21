import 'package:mempool/src/domain/mempool_failure.dart';
import 'package:mempool/src/domain/value_objects/mempool_server_network.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

abstract class MempoolServerValidatorPort {
  /// Validates that [url] is a reachable mempool server. `Ok` means valid;
  /// `Err` carries a typed [MempoolFailure] variant describing the specific reason.
  @useResult
  Future<Result<void, MempoolFailure>> validateServer({
    required String url,
    required MempoolServerNetwork network,
    bool enableSsl = true,
  });
}
