class SecretValidator {
  static const int minSecretLength = 6;

  bool hasValidLength(String secret) => secret.length >= minSecretLength;
  bool areSecretsMatching(String secret, String confirmSecret) =>
      secret == confirmSecret;
}
