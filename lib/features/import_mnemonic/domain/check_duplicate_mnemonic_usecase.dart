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
      // `idOf` derives the identity without storing anything, and
      // `exists` answers in one read — a wrong "no" here lets a
      // duplicate through, which is cheap, so it does not pay for the
      // retry budget a seed read does.
      // Words that are not a mnemonic cannot have an identity; the package says so as a failure, reported here in this feature's own vocabulary.
      final Fingerprint id;
      switch (await _secrets.idOf(
        words: mnemonicWords,
        passphrase: passphrase,
      )) {
        case Ok(:final value):
          id = value;
        case Err(:final failure):
          return Err(ImportMnemonicUnexpectedFailure(failure.toString()));
      }

      return switch (await _secrets.exists(id)) {
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
