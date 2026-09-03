import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;

class GenerateBullVaultInheritanceMnemonicUsecase {
  const GenerateBullVaultInheritanceMnemonicUsecase();

  Result<List<String>, BullVaultFailure> execute() {
    try {
      return Ok(
        List.unmodifiable(
          bip39.Mnemonic.generate(
            bip39.Language.english,
            length: bip39.MnemonicLength.words24,
          ).words,
        ),
      );
    } on Exception {
      return const Err(BullVaultCreationFailure());
    }
  }
}
