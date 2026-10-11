import 'package:primitives/primitives.dart' show Result;
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:secrets/secrets.dart'
    show EphemeralMnemonic, MnemonicLength, Secrets;

class GenerateBullVaultInheritanceMnemonicUsecase {
  final Secrets _secrets;

  const GenerateBullVaultInheritanceMnemonicUsecase(this._secrets);

  Future<Result<EphemeralMnemonic, BullVaultFailure>> execute() async =>
      (await _secrets.generateEphemeral(
        wordCount: MnemonicLength.words24,
      )).mapErr((_) => const BullVaultCreationFailure());
}
