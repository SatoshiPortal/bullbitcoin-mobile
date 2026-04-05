class EnvVar {
  final String name;
  final bool isRequired;
  const EnvVar(this.name, {this.isRequired = false});
}

class EnvValidator {
  static const _vars = [
    EnvVar('BB_API_URL'),
    EnvVar('BB_API_TEST_URL'),
    EnvVar('BB_AUTH_URL', isRequired: true),
    EnvVar('BB_AUTH_TEST_URL', isRequired: true),
    EnvVar('BBX_URL'),
    EnvVar('BBX_TEST_URL'),
    EnvVar('APIKEY_QUERY_PARAM'),
    EnvVar('BASIC_AUTH_USERNAME'),
    EnvVar('BASIC_AUTH_PASSWORD'),
    EnvVar('GOOGLE_DRIVE_CLIENT_ID'),
    EnvVar('GOOGLE_DRIVE_URL_SCHEME'),
    EnvVar('SENTRY_DSN'),
    EnvVar('TEST_ALICE_MNEMONIC'),
    EnvVar('TEST_BOB_MNEMONIC'),
  ];

  // We throw error when an unknown variable is encountered because this being
  // a frontend app, any variable added to the .env is extractable by users if
  // they decode the APK(s) published via GitHub or Google Play Store. If a
  // sensitive API key was added by mistake for example, that can be a problem
  static List<String> validate(Map<String, String> env) {
    final knownKeys = _vars.map((v) => v.name).toSet();
    final errors = <String>[];
    for (final key in env.keys) {
      if (!knownKeys.contains(key)) errors.add('Unknown variable: $key');
    }
    for (final v in _vars.where((v) => v.isRequired)) {
      final value = env[v.name];
      if (value == null || value.trim().isEmpty) {
        errors.add('Required variable missing or empty: ${v.name}');
      }
    }
    return errors;
  }
}
