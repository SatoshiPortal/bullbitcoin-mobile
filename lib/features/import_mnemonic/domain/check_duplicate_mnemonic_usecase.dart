import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/features/import_mnemonic/errors.dart';

class CheckDuplicateMnemonicUsecase {
  final SeedRepository _seedRepository;

  CheckDuplicateMnemonicUsecase({required SeedRepository seedRepository})
    : _seedRepository = seedRepository;

  Future<void> execute({
    required List<String> mnemonicWords,
    String passphrase = '',
  }) async {
    final fingerprint = _seedRepository.fingerprintFor(
      mnemonicWords: mnemonicWords,
      passphrase: passphrase,
    );
    if (await _seedRepository.exists(fingerprint)) {
      throw DuplicateMnemonicException();
    }
  }
}
