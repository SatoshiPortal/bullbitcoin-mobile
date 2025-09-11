import 'dart:io';

import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';

class FetchEncryptedVaultFromFileSystemUsecase {
  FetchEncryptedVaultFromFileSystemUsecase();

  Future<EncryptedVault> execute(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw 'File does not exist';
      }
      final fileContent = await file.readAsString();

      if (!EncryptedVault.isValid(fileContent)) {
        throw 'File is not a valid encrypted vault';
      }

      return EncryptedVault(file: fileContent);
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
