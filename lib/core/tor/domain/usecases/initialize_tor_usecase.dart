import 'package:bb_mobile/core/tor/domain/repositories/tor_repository.dart';

class InitializeTorUsecase {
  final TorRepository _torRepository;

  InitializeTorUsecase(this._torRepository);

  Future<void> execute() async {
    try {
      await _torRepository.start();
    } catch (e) {
      throw Exception('Failed to initialize Tor: $e');
    }
  }
}
