import 'package:bb_mobile/core_deprecated/electrum/application/dtos/requests/delete_custom_server_request.dart';
import 'package:bb_mobile/core_deprecated/electrum/domain/repositories/electrum_server_repository.dart';

class DeleteCustomServerUsecase {
  final ElectrumServerRepository _electrumServerRepository;

  DeleteCustomServerUsecase({
    required ElectrumServerRepository electrumServerRepository,
  }) : _electrumServerRepository = electrumServerRepository;

  Future<void> execute(DeleteCustomServerRequest request) async {
    await _electrumServerRepository.delete(url: request.url);
  }
}
