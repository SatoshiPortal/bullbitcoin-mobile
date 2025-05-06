import 'package:bb_mobile/core/electrum/data/repository/electrum_server_repository_impl.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:flutter/foundation.dart';

class UpdateElectrumServerSettingsUsecase {
  final ElectrumServerRepository _electrumServerRepository;

  const UpdateElectrumServerSettingsUsecase({
    required ElectrumServerRepository electrumServerRepository,
  }) : _electrumServerRepository = electrumServerRepository;

  Future<bool> execute({required ElectrumServer electrumServer}) async {
    try {
      await _electrumServerRepository.setElectrumServer(electrumServer);
      debugPrint('\n Successfully updated Electrum server settings');

      return true;
    } catch (e) {
      debugPrint('Error updating Electrum server settings: $e');
      return false;
    }
  }
}
