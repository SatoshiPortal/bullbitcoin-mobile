import '../entities/tor_session.dart';
import '../tor_repository.dart';

class OpenTorSessionUsecase {
  final TorRepository _repository;

  const OpenTorSessionUsecase(this._repository);

  Future<TorSession> execute({Duration? connectTimeout}) =>
      _repository.openSession(connectTimeout: connectTimeout);
}
