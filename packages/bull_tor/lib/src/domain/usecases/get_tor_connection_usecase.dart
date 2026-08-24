import '../entities/tor_connection_state.dart';
import '../tor_repository.dart';

class GetTorConnectionUsecase {
  final TorRepository _repository;

  const GetTorConnectionUsecase(this._repository);

  TorConnectionState execute() => _repository.current;
}
