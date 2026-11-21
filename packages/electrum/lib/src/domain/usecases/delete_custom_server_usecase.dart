import 'package:electrum/src/domain/delete_custom_server_request.dart';
import 'package:electrum/src/domain/electrum_failure.dart';
import 'package:electrum/src/domain/repositories/electrum_server_repository.dart';
import 'package:primitives/primitives.dart' show Result;
import 'package:meta/meta.dart';

class DeleteCustomServerUsecase {
  final ElectrumServerRepository _electrumServerRepository;

  DeleteCustomServerUsecase({required this._electrumServerRepository});

  @useResult
  Future<Result<void, ElectrumFailure>> execute(
    DeleteCustomServerRequest request,
  ) => _electrumServerRepository.delete(
    url: request.url,
    network: request.network,
  );
}
