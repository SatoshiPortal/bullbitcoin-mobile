import 'package:bb_mobile/_core/domain/repositories/tor_repository.dart';

class InitializeTorUseCase {
  final TorRepository _torRepository;

  InitializeTorUseCase(this._torRepository);

  Future<void> execute() async {
    //do a try catch over here
    await _torRepository.isTorReady();
  }
}
