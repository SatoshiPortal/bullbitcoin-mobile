import 'package:bb_mobile/key_server/domain/validators/secret_validator.dart';

class Key {
  final String value;

  Key._(this.value);

  static Key? create(String value) {
    if (value.isEmpty) return null;
    if (value.length < KeyValidator.minKeyLength) return null;
    return Key._(value);
  }
}
