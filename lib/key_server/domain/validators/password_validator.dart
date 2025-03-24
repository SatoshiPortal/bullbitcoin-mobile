import 'package:bb_mobile/key_server/data/constants/most_common_passwords.dart';

class RecoverBullPasswordValidator {
  /// Returns `true` if the given password is part of the top most common passwords
  static bool isInCommonPasswordList(String password) {
    return commonPasswordsTop1000.contains(password);
  }
}
