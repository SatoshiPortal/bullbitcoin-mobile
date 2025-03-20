import 'package:bb_mobile/recoverbull/domain/validators/secret_validator.dart';

class Secret {
  final String value;

  Secret._(this.value);

  static Secret? create(String value) {
    if (value.isEmpty) return null;
    if (value.length < SecretValidator.minSecretLength) return null;
    return Secret._(value);
  }
}
