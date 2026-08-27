import '../entities/tor_connection_state.dart';
import '../tor_repository.dart';

class WatchTorConnectionUsecase {
  final TorRepository _repository;

  const WatchTorConnectionUsecase(this._repository);

  Stream<TorConnectionState> execute() => _repository.watch();
}
