import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/features/recoverbull/utils/most_common_passwords.dart';
import 'package:flutter/material.dart';

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

  static String? validateLength(String password, BuildContext context) {
    if (hasValidLength(password)) return null;
    return context.loc.recoverbullPasswordTooShort;
  }

  static String? validateNotCommon(String password, BuildContext context) {
    if (!isTooCommon(password)) return null;
    return context.loc.recoverbullPasswordTooCommon;
  }

  static String? validateMatching(String password, String confirmPassword, BuildContext context) {
    if (areMatching(password, confirmPassword)) return null;
    return context.loc.recoverbullPasswordMismatch;
  }

  static String? validate(String? password, BuildContext context) {
    if (password == null) return context.loc.recoverbullPasswordRequired;
    final length = validateLength(password, context);
    if (length != null) return length;
    final isCommon = validateNotCommon(password, context);
    if (isCommon != null) return isCommon;
    return null;
  }
}
