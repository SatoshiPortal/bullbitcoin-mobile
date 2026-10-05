import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class GetMnemonicFromFingerprintUsecase {
  final SeedRepository _seedRepository;

  GetMnemonicFromFingerprintUsecase({required this._seedRepository});

  /// The mnemonic words and passphrase stored for [fingerprint].
  ///
  /// The secret is returned to the caller and deliberately never stored in
  /// bloc state — see `TestWalletBackupBloc.loadSelectedWalletMnemonic`.
  @useResult
  Future<Result<(List<String>, String?), TestWalletBackupFailure>> execute(
    String fingerprint,
  ) async {
    try {
      final seed = await _seedRepository.get(fingerprint);
      final seedModel = SeedModel.fromEntity(seed);
      if (seedModel is! MnemonicSeedModel) {
        return const Err(TestWalletBackupSeedNotMnemonicFailure());
      }

      return Ok((seedModel.mnemonicWords, seedModel.passphrase));
    } on Object catch (e, st) {
      // warning, not severe: severe forwards the exception to the crash
      // reporter (see Logger.severe), and this is the seed read path — the
      // driver's message is not guaranteed to be free of the value it failed
      // on, so it must not leave the device. warning stays local.
      log.warning(
        'Failed to read the mnemonic for the backup test',
        error: e,
        trace: st,
      );
      // The failure carries NO logMessage on purpose. It is stored in bloc
      //  state, and this is the seed read path: the thrown reason comes
      //  straight from the secure-storage driver and is not guaranteed to be
      //  free of the value it failed on. It is logged above and goes no
      //  further. (Failure has no toString() today, so logMessage would not
      //  print in a state dump — but relying on that is one debug helper away
      //  from a disclosure.)
      return const Err(TestWalletBackupSeedUnavailableFailure());
    }
  }
}
