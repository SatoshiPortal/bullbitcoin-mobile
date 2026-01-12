import 'package:bb_mobile/core/primitives/secrets/secret.dart';

abstract interface class SecretCryptoPort {
  Future<String> getFingerprintFromSecret(Secret secret);
}
