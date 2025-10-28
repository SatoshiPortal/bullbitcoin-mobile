import 'dart:convert';

import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';

class DecryptVaultUsecase {
  final RecoverBullRepository _recoverBull;

  DecryptVaultUsecase({required RecoverBullRepository recoverBullRepository})
    : _recoverBull = recoverBullRepository;

  DecryptedVault execute({
    required EncryptedVault vault,
    required String vaultKey,
  }) {
    final plaintext = _recoverBull.restoreJsonVault(vault.toFile(), vaultKey);

    final decodedPlaintext = json.decode(plaintext) as Map<String, dynamic>;
    final decryptedVault = DecryptedVault.fromJson(decodedPlaintext);
    return decryptedVault;
  }
}
