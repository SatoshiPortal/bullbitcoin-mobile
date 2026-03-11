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
        MnemonicSeedModel(:final mnemonicWords, :final passphrase) => (
          mnemonicWords,
          passphrase,
        ),
        _ => throw Exception('selected seed is not a mnemonic seed'),
      };

      return (mnemonicWords, passphrase);
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      rethrow;
    }
  }
}
