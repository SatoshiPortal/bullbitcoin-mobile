import '../tor_repository.dart';

class CloseTorUsecase {
  final TorRepository _repository;

  const CloseTorUsecase(this._repository);

  Future<void> execute() => _repository.close();
}
