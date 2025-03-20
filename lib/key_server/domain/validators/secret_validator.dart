class KeyValidator {
  static const int minKeyLength = 6;

  bool hasValidLength(String key) => key.length >= minKeyLength;
  bool areKeysMatching(String key, String confirmKey) => key == confirmKey;
}
