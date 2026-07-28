import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:meta/meta.dart';

class GetMnemonicFromFingerprintUsecase {
  final SeedRepository _seedRepository;

  GetMnemonicFromFingerprintUsecase({required this._seedRepository});

  @useResult
  Future<Result<(List<String>, String?), TestWalletBackupFailure>> execute(
    String fingerprint,
  ) async {
    try {
      final seed = await _seedRepository.get(fingerprint);
      final defaultSeedModel = SeedModel.fromEntity(seed);

      return switch (defaultSeedModel) {
        MnemonicSeedModel(:final mnemonicWords, :final passphrase) => Ok((
          mnemonicWords,
          passphrase,
        )),
        _ => const Err(
          TestWalletBackupLoadMnemonicFailure(
            'Selected seed is not a mnemonic seed',
          ),
        ),
      };
    } on Exception catch (error, trace) {
      log.severe(
        message: 'getMnemonicFromFingerprint failed',
        error: error,
        trace: trace,
      );
      return Err(TestWalletBackupLoadMnemonicFailure(error.toString()));
    }
  }
}
