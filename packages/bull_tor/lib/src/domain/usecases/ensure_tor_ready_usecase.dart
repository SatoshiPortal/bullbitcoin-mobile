import '../entities/tor_connection_state.dart';
import '../tor_repository.dart';

class EnsureTorReadyUsecase {
  final TorRepository _repository;

  const EnsureTorReadyUsecase(this._repository);

  Future<TorConnectionState> execute() => _repository.ensureReady();
}
