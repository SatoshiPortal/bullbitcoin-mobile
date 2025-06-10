class NoteValidator {
  static const int maxNoteLength = 50;

  /// Simple validation that checks length and forbidden characters
  static ValidationResult validate(String note) {
    final trimmedNote = note.trim();

    // Check length
    if (trimmedNote.length > maxNoteLength) {
      return ValidationResult(
        isValid: false,
        errorMessage:
            'Note must be no more than $maxNoteLength characters (currently ${trimmedNote.length})',
      );
    }
    final forbiddenCharacters = hasForbiddenCharacters(note);
    // Check for forbidden special characters
    if (forbiddenCharacters != null) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Note contains forbidden character: $forbiddenCharacters',
      );
    }

    return const ValidationResult(isValid: true);
  }

  /// Check if note contains forbidden characters
  static String? hasForbiddenCharacters(String note) {
    const forbiddenChars = [
      'ù',
      'ë',
      'ç',
      '{',
      '}',
      '[',
      ']',
      '<',
      '>',
      '^',
      '*',
      '|',
      '\\',
      '/',
      ':',
      ';',
      '"',
      "'",
      '`',
      '~',
    ];

    for (final char in forbiddenChars) {
      if (note.contains(char)) {
        return char;
      }
    }
    return null;
  }
}

class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult({required this.isValid, this.errorMessage});
}
