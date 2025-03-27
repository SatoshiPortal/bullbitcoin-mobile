import 'package:bb_mobile/core/domain/repositories/tor_repository.dart';

class InitializeTorUsecase {
  final TorRepository _torRepository;

  InitializeTorUsecase(this._torRepository);

  Future<void> execute() async {
    //do a try catch over here
    await _torRepository.start();
  }
}
