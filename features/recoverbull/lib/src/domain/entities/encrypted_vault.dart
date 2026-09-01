import 'package:convert/convert.dart' as convert;
import 'package:recoverbull/recoverbull.dart' as recoverbull;

import '../../support/errors.dart';

class EncryptedVault {
  late recoverbull.BullBackup backup;

  EncryptedVault({required String file}) {
    backup = recoverbull.BullBackup.fromJson(file);
  }

  String toFile() => backup.toJson();

  static bool isValid(String file) => recoverbull.BullBackup.isValid(file);

  String get salt => convert.hex.encode(backup.salt);

  String get derivationPath {
    if (backup.path == null) throw EncryptedVaultMissingPath();
    return backup.path!;
  }

  String get id => convert.hex.encode(backup.id);

  DateTime get createdAt =>
      DateTime.fromMillisecondsSinceEpoch(backup.createdAt);

  String get filename =>
      '${createdAt.toIso8601String().substring(0, 10)}_encrypted_vault.json';
}

class EncryptedVaultException extends RecoverBullDataException {
  EncryptedVaultException(super.message);
}

class EncryptedVaultMissingPath extends RecoverBullDataException {
  EncryptedVaultMissingPath()
    : super('Encrypted vault derivationPath is missing path');
}
