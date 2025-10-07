import 'package:bb_mobile/core/electrum/data/repository/electrum_server_repository_impl.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';

class CheckElectrumServerConnectivityUsecase {
  final ElectrumServerRepository _electrumServerRepository;

  CheckElectrumServerConnectivityUsecase({
    required ElectrumServerRepository electrumServerRepository,
  }) : _electrumServerRepository = electrumServerRepository;

  /// Checks if a connection can be established to the specified Electrum server.
  ///
  /// Returns the status of the server (online, offline, or unknown).
  Future<ElectrumServerStatus> execute({
    required String url,
    int? timeout,
  }) async {
    return await _electrumServerRepository.checkServerConnectivity(
      url: url,
      timeout: timeout,
    );
  }
}
