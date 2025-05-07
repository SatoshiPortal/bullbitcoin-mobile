import 'package:bb_mobile/core/electrum/data/repository/electrum_server_repository_impl.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:flutter/foundation.dart';

class StoreElectrumServerSettingsUsecase {
  final ElectrumServerRepository _repository;

  const StoreElectrumServerSettingsUsecase({
    required ElectrumServerRepository repository,
  }) : _repository = repository;

  Future<bool> execute({required ElectrumServer electrumServer}) async {
    try {
      await _repository.storeElectrumServer(server: electrumServer);
      return true;
    } catch (e) {
      debugPrint('Error storing or updating Electrum server settings: $e');
      return false;
    }
  }
}
