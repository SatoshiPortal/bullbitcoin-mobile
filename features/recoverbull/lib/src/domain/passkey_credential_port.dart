import 'package:primitives/primitives.dart';

import 'entities/vault_passkey.dart';
import 'passkey_secret_port.dart';
import 'recoverbull_failure.dart';

abstract interface class PasskeyCredentialPort implements PasskeySecretPort {
  Future<Result<VaultPasskey, RecoverBullFailure>> create();

  Future<void> cancel();
}
