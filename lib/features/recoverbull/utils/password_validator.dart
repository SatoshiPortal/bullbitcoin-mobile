import 'package:bb_mobile/features/recoverbull/utils/most_common_passwords.dart';

class PasswordValidator {
  static const int minPasswordLength = 6;

  static bool hasValidLength(String password) =>
      password.length >= minPasswordLength;

  static bool areMatching(String password, String confirmPassword) =>
      password == confirmPassword;

  static bool isTooCommon(String password) =>
      commonPasswordsTop1000.contains(password);

  static bool isValid(String password) =>
      hasValidLength(password) && !isTooCommon(password);

  static String? validateLength(String password) {
    if (hasValidLength(password)) return null;
    return 'Password must be at least 6 characters long';
  }

  static String? validateNotCommon(String password) {
    if (!isTooCommon(password)) return null;
    return 'This password is too common. Please choose a different one';
  }

  static String? validateMatching(String password, String confirmPassword) {
    if (areMatching(password, confirmPassword)) return null;
    return 'Passwords do not match';
  }

  static String? validate(String? password) {
    if (password == null) return 'Password is required';
    final length = validateLength(password);
    if (length != null) return length;
    final isCommon = validateNotCommon(password);
    if (isCommon != null) return isCommon;
    return null;
  }
}
