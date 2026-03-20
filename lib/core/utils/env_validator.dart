class EnvValidator {
  // key: variable name, value: is required
  static const _vars = {
    'BB_API_URL': false,
    'BB_API_TEST_URL': false,
    'BB_AUTH_URL': true,
    'BB_AUTH_TEST_URL': true,
    'BBX_URL': false,
    'BBX_TEST_URL': false,
    'APIKEY_QUERY_PARAM': false,
    'BASIC_AUTH_USERNAME': false,
    'BASIC_AUTH_PASSWORD': false,
    'GOOGLE_DRIVE_CLIENT_ID': false,
    'GOOGLE_DRIVE_URL_SCHEME': false,
    'SENTRY_DSN': false,
    'TEST_ALICE_MNEMONIC': false,
    'TEST_BOB_MNEMONIC': false,
  };

  static List<String> validate(Map<String, String> env) {
    final errors = <String>[];

    for (final key in env.keys) {
      if (!_vars.containsKey(key)) {
        errors.add('Unknown variable: $key');
      }
    }

    for (final entry in _vars.entries) {
      if (!entry.value) continue;
      final value = env[entry.key];
      if (value == null || value.trim().isEmpty) {
        errors.add('Required variable missing or empty: ${entry.key}');
      }
    }

    return errors;
  }
}
