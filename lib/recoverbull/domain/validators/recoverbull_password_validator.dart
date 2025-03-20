import 'package:bb_mobile/recoverbull/data/most_common_passwords.dart';

class RecoverBullPasswordValidator {
  /// Returns `true` if the given password is part of the top most common passwords
  static bool isInCommonPasswordList(String password) {
    return commonPasswordsTop1000.contains(password);
  }
}
