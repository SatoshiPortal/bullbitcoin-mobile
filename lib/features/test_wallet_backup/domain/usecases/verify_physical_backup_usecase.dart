import 'package:bb_mobile/core/seed/data/models/seed_model.dart'
    show MnemonicSeedModel, SeedModel;
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class VerifyPhysicalBackupUsecase {
  final SeedRepository _seedRepository;

  VerifyPhysicalBackupUsecase({required this._seedRepository});

  /// Compares [mnemonic] against the seed stored for [fingerprint].
  ///
  /// The stored secret is read at the point of use and never leaves this
  /// method; only the comparison result is returned.
  Future<bool> execute({
    required String fingerprint,
    required List<String> mnemonic,
  }) async {
    try {
      final seed = await _seedRepository.get(fingerprint);
      final seedModel = SeedModel.fromEntity(seed);
      final mnemonicWords = switch (seedModel) {
        MnemonicSeedModel(:final mnemonicWords) => mnemonicWords,
        _ => throw Exception('Selected seed is not a mnemonic seed'),
      };

      return mnemonic.length == mnemonicWords.length &&
          List.generate(
            mnemonic.length,
            (i) => mnemonic[i] == mnemonicWords[i],
          ).every((element) => element);
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      rethrow;
    }
  }
}
