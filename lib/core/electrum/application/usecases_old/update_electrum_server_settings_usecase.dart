import 'package:bb_mobile/core/electrum/data/repository/electrum_server_repository_impl.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';

class UpdateElectrumServerSettingsUsecase {
  final ElectrumServerRepository _repository;

  const UpdateElectrumServerSettingsUsecase({
    required ElectrumServerRepository repository,
  }) : _repository = repository;

  Future<bool> execute({required ElectrumServer electrumServer}) async {
    try {
      await _repository.updateElectrumServer(server: electrumServer);
      return true;
    } catch (e) {
      return false;
    }
  }
}
