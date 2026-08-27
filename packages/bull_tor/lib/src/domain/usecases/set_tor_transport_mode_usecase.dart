import '../entities/tor_connection_state.dart';
import '../entities/tor_transport.dart';
import '../tor_repository.dart';

class SetTorTransportModeUsecase {
  final TorRepository _repository;

  const SetTorTransportModeUsecase(this._repository);

  Future<TorConnectionState> execute(TorTransportMode mode) =>
      _repository.setMode(mode);
}
