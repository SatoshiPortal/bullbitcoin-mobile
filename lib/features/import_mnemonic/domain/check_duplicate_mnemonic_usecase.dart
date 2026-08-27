import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:meta/meta.dart';

class CheckDuplicateMnemonicUsecase {
  final SeedRepository _seedRepository;

  CheckDuplicateMnemonicUsecase({required this._seedRepository});

  @useResult
  Future<Result<void, ImportMnemonicFailure>> execute({
    required List<String> mnemonicWords,
    String passphrase = '',
  }) async {
    try {
      final fingerprint = _seedRepository.fingerprintFor(
        mnemonicWords: mnemonicWords,
        passphrase: passphrase,
      );
      if (await _seedRepository.exists(fingerprint)) {
        return const Err(ImportMnemonicDuplicateFailure());
      }
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'Duplicate mnemonic check failed',
        error: e,
        trace: st,
      );
      return Err(ImportMnemonicUnexpectedFailure(e.toString()));
    }
  }
}
