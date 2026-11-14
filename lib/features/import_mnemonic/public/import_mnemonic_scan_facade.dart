import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart'
    show ScriptType;
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/scan_mnemonic_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Language;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Result, Ok, Err;

export '../domain/import_mnemonic_failure.dart'
    show ImportMnemonicScanFailure, ImportMnemonicScanTimeoutFailure;

/// Bitcoin history scan used before restoring a default wallet.
class ImportMnemonicScanFacade {
  @internal
  const ImportMnemonicScanFacade(this._scan);
  final ScanMnemonicUsecase _scan;

  @useResult
  Future<Result<bool, ImportMnemonicScanFailure>> hasBitcoinHistory({
    required List<String> words,
    required String passphrase,
  }) async {
    final scan = _scan.execute(
      words: words,
      language: Language.english,
      passphrase: passphrase,
      scriptTypes: {ScriptType.bip84},
    )[ScriptType.bip84];
    if (scan == null) {
      return const Err(ImportMnemonicScanUnexpectedFailure('Missing scan'));
    }
    return switch (await scan) {
      Ok(:final value) => Ok(value.transactions > 0),
      Err(:final failure) => Err(failure),
    };
  }
}
