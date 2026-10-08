import '../entities/tor_transport_fallback.dart';
import '../tor_repository.dart';

class WatchTorTransportFallbacksUsecase {
  final TorRepository _repository;

  const WatchTorTransportFallbacksUsecase(this._repository);

  Stream<TorTransportFallback> execute() => _repository.watchFallbacks();
}
