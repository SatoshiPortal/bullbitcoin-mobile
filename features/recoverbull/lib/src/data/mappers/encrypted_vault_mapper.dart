import 'package:convert/convert.dart' as convert;
import '../../domain/entities/encrypted_vault.dart';
import '../models/encrypted_vault_model.dart';

final class EncryptedVaultMapper {
  static EncryptedVault toEntity(EncryptedVaultModel model) => EncryptedVault(
    id: convert.hex.encode(model.id),
    salt: convert.hex.encode(model.salt),
    ciphertext: model.ciphertext,
    createdAt: DateTime.fromMillisecondsSinceEpoch(model.createdAt),
    derivationPath: model.path,
  );
  static EncryptedVaultModel fromEntity(EncryptedVault vault) =>
      EncryptedVaultModel(
        createdAt: vault.createdAt.millisecondsSinceEpoch,
        id: convert.hex.decode(vault.id),
        salt: convert.hex.decode(vault.salt),
        ciphertext: vault.ciphertext,
        path: vault.derivationPath,
      );
  static EncryptedVault parse(String file) =>
      toEntity(EncryptedVaultModel.fromFile(file));
}
