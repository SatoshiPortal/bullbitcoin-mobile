import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

class CheckDuplicateMnemonicUsecase {
  final Secrets _secrets;

  CheckDuplicateMnemonicUsecase({required this._secrets});

  @useResult
  Future<Result<void, ImportMnemonicFailure>> execute({
    required List<String> mnemonicWords,
    String passphrase = '',
  }) async {
    try {
      // This preflight avoids an unnecessary wallet scan. The strict import
      // remains responsible for rejecting a duplicate at the time of storage.
      return switch (await _secrets.contains(
        words: mnemonicWords,
        passphrase: passphrase,
      )) {
        Ok(value: true) => const Err(ImportMnemonicDuplicateFailure()),
        Ok() => const Ok(null),
        Err(:final failure) => Err(
          ImportMnemonicUnexpectedFailure(failure.toString()),
        ),
      };
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
