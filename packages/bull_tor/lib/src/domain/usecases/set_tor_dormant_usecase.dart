import '../tor_repository.dart';

class SetTorDormantUsecase {
  final TorRepository _repository;

  const SetTorDormantUsecase(this._repository);

  Future<void> execute(bool dormant) => _repository.setDormant(dormant);
}
