import '../entities/tor_connection_state.dart';
import '../tor_repository.dart';

class RetryTorConnectionUsecase {
  final TorRepository _repository;

  const RetryTorConnectionUsecase(this._repository);

  Future<TorConnectionState> execute() => _repository.retry();
}
