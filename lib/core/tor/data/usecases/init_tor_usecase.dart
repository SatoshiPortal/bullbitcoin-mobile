import 'package:bb_mobile/core/tor/data/repository/tor_repository.dart';

class InitTorUsecase {
  final TorRepository _torRepository;

  InitTorUsecase(this._torRepository);

  Future<void> execute() async {
    try {
      await _torRepository.start();
    } catch (e) {
      throw Exception('$InitTorUsecase: $e');
    }
  }
}
