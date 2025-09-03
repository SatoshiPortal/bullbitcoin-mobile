import 'dart:io';

import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';

class FetchEncryptedVaultFromFileSystemUsecase {
  FetchEncryptedVaultFromFileSystemUsecase();

  Future<EncryptedVault> execute(String filePath) async {
    try {
      final backupFile = File(filePath);
      if (!await backupFile.exists()) {
        throw 'File does not exist';
      }
      final backupFileContent = await backupFile.readAsString();

      if (!EncryptedVault.isValid(backupFileContent)) {
        throw 'File is not a valid encrypted vault';
      }
      return EncryptedVault(file: backupFileContent);
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
