import 'package:bb_mobile/key_server/data/constants/most_common_passwords.dart';

class KeyValidator {
  static const int minKeyLength = 6;

  bool hasValidLength(String key) => key.length >= minKeyLength;
  bool areKeysMatching(String key, String confirmKey) => key == confirmKey;
  bool isInCommonPasswordList(String password) =>
      commonPasswordsTop1000.contains(password);
}
