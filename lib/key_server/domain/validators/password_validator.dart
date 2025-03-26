import 'package:bb_mobile/key_server/data/constants/most_common_passwords.dart';

class PasswordValidator {
  static const int minPasswordLength = 6;

  bool hasValidLength(String password) => password.length >= minPasswordLength;
  bool arePasswordsMatching(String password, String confirmPassword) =>
      password == confirmPassword;
  bool isInCommonPasswordList(String password) =>
      commonPasswordsTop1000.contains(password);
}
