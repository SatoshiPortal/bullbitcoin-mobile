import 'package:bb_mobile/core/electrum/data/repository/electrum_server_repository_impl.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';

class UpdateElectrumServerSettingsUsecase {
  final ElectrumServerRepository _repository;

  const UpdateElectrumServerSettingsUsecase({
    required ElectrumServerRepository repository,
  }) : _repository = repository;

  Future<bool> execute({
    required ElectrumServer electrumServer,
    required String previousUrl,
  }) async {
    try {
      await _repository.updateElectrumServer(
        server: electrumServer,
        existingIndex: previousUrl,
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}
