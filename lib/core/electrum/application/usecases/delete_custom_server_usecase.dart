import 'package:bb_mobile/core/electrum/application/dtos/requests/delete_custom_server_request.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_failure.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class DeleteCustomServerUsecase {
  final ElectrumServerRepository _electrumServerRepository;

  DeleteCustomServerUsecase({
    required this._electrumServerRepository,
  });

  @useResult
  Future<Result<void, ElectrumFailure>> execute(
    DeleteCustomServerRequest request,
  ) =>
      _electrumServerRepository.delete(url: request.url);
}
