import 'dart:typed_data';

import 'package:primitives/primitives.dart';

import 'entities/vault_passkey.dart';
import 'recoverbull_failure.dart';

/// Produces a local PRF result for the exact stored credential.
abstract interface class PasskeySecretPort {
  Future<Result<Uint8List, RecoverBullFailure>> get(VaultPasskey passkey);
}
