import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';

class UpdateElectrumServerSettingsUsecase {
  final ElectrumServerRepository _electrumServerRepository;
  const UpdateElectrumServerSettingsUsecase({
    required ElectrumServerRepository electrumServerRepository,
  }) : _electrumServerRepository = electrumServerRepository;

  Future<void> execute({
    required ElectrumServer electrumServer,
  }) async {
    await _electrumServerRepository.setElectrumServer(electrumServer);
  }
}
