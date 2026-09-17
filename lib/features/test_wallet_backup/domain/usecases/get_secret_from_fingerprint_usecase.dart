import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Fingerprint;
import 'package:secrets/secrets.dart';

class GetSecretFromFingerprintUsecase {
  final Secrets _secrets;

  GetSecretFromFingerprintUsecase({required this._secrets});

  /// Finds the wallet's secret handle.
  ///
  /// A handle, not the words: the mnemonic is read inside `MnemonicView` and
  /// `MnemonicChallenge` at the moment it is drawn, and there is no longer an
  /// app path that could hold it. This usecase is what makes that possible —
  /// it carries a description and a reference, both safe to keep.
  @useResult
  Future<Result<Secret, TestWalletBackupFailure>> execute(
    String fingerprint,
  ) async {
    switch (await _secrets.fetch(Fingerprint(fingerprint))) {
      case Ok(:final value):
        if (!value.info.isMnemonic) {
          return const Err(TestWalletBackupSeedNotMnemonicFailure());
        }
        return Ok(value);
      case Err(:final failure):
        // The type only: the package never puts material in a failure, and
        // this one is kept in bloc state.
        log.warning('Backup test: secret unavailable (${failure.runtimeType})');
        return const Err(TestWalletBackupSeedUnavailableFailure());
    }
  }
}
