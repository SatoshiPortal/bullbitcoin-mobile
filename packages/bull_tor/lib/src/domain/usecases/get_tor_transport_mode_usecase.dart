import '../entities/tor_transport.dart';
import '../tor_repository.dart';

class GetTorTransportModeUsecase {
  final TorRepository _repository;

  const GetTorTransportModeUsecase(this._repository);

  TorTransportMode execute() => _repository.mode;
}
