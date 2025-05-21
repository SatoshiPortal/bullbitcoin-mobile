import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class GetMnemonicFromFingerprintUsecase {
  final SeedRepository _seedRepository;

  GetMnemonicFromFingerprintUsecase({required SeedRepository seedRepository})
    : _seedRepository = seedRepository;

  Future<List<String>> execute(String fingerprint) async {
    try {
      final seed = await _seedRepository.get(fingerprint);
      final defaultSeedModel = SeedModel.fromEntity(seed);

      final mnemonicWords = switch (defaultSeedModel) {
        MnemonicSeedModel(:final mnemonicWords) => mnemonicWords,
        _ => throw Exception('selected seed is not a mnemonic seed'),
      };

      return mnemonicWords;
    } catch (e) {
      debugPrint('GetMnemonicFromFingerprintUsecase: $e');
      rethrow;
    }
  }
}
