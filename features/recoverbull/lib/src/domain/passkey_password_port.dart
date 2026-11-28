import 'dart:typed_data';

import 'entities/encrypted_vault.dart';

abstract interface class PasskeyPasswordPort {
  String derive(Uint8List prf, EncryptedVault vault);
}
