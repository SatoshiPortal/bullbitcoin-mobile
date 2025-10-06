import 'package:bb_mobile/core/electrum/data/repository/electrum_server_repository_impl.dart';

class DeleteElectrumServerUsecase {
  final ElectrumServerRepository _electrumServerRepository;

  const DeleteElectrumServerUsecase({
    required ElectrumServerRepository electrumServerRepository,
  }) : _electrumServerRepository = electrumServerRepository;

  Future<bool> execute({required String url}) async {
    return await _electrumServerRepository.deleteElectrumServer(url: url);
  }
}
