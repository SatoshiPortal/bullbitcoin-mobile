import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/import_wallet_usecase.dart';

class CheckDuplicateMnemonicUsecase {
  final SeedRepository _seedRepository;

  CheckDuplicateMnemonicUsecase({required SeedRepository seedRepository})
    : _seedRepository = seedRepository;

  Future<void> call({
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
