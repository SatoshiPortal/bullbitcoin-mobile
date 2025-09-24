import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class GetMnemonicFromFingerprintUsecase {
  final SeedRepository _seedRepository;

  GetMnemonicFromFingerprintUsecase({required SeedRepository seedRepository})
    : _seedRepository = seedRepository;

  Future<(List<String>, String?)> execute(String fingerprint) async {
    try {
      final seed = await _seedRepository.get(fingerprint);
      final defaultSeedModel = SeedModel.fromEntity(seed);

      final (mnemonicWords, passphrase) = switch (defaultSeedModel) {
        EntropySeedModel() => (seed.toMnemonic().words, seed.passphrase),
      };

      return (mnemonicWords, passphrase);
    } catch (e) {
      log.severe('GetMnemonicFromFingerprintUsecase: $e');
      rethrow;
    }
  }
}
