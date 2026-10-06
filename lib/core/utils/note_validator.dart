/// Why a user-entered note is not acceptable.
///
/// Deliberately not a `Failure`, an `Error` or an `Exception`: this is a
/// shared, Flutter-free description of a broken rule, which each feature maps
/// into its own failure family and translates in its own presentation
/// extension. Returning a message from here is what previously put hardcoded
/// English into state and onto the screen.
sealed class NoteViolation {
  const NoteViolation();
}

/// The note is longer than [maxLength] once trimmed.
///
/// Carries the limit but not the actual length: the old message said
/// "(currently 63)", and nothing renders that now. Add it back with the
/// message that needs it rather than leaving a field no caller reads.
final class NoteTooLong extends NoteViolation {
  final int maxLength;

  const NoteTooLong({required this.maxLength});
}

/// The note contains [character], which cannot travel in a BIP21 URI.
///
/// [character] is the user's own input, not an internal detail, so it is safe
/// to show back to them.
final class NoteForbiddenCharacter extends NoteViolation {
  final String character;

  const NoteForbiddenCharacter(this.character);
}

class NoteValidator {
  /// Kept in step with `LabelEntity.maxLabelLength`, which truncates to the
  /// same bound when a label arrives from an import rather than from this
  /// form. The two are separate constants because one rejects and the other
  /// sanitizes; if either moves, both must.
  static const int maxNoteLength = 50;

  /// The rule the note breaks, or null when it is acceptable.
  ///
  /// Length is measured on the trimmed note — surrounding whitespace is not
  /// the user's mistake — but forbidden characters are looked for in the raw
  /// note, so a leading tab or newline is still caught. Length is checked
  /// first, so a note that breaks both is reported as too long.
  static NoteViolation? validate(String note) {
    final trimmedNote = note.trim();

    if (trimmedNote.length > maxNoteLength) {
      return const NoteTooLong(maxLength: maxNoteLength);
    }

    final forbiddenCharacter = hasForbiddenCharacters(note);
    if (forbiddenCharacter != null) {
      return NoteForbiddenCharacter(forbiddenCharacter);
    }

    return null;
  }

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
      '\n',
      '\t',
      '\r',
    ];

    for (final char in forbiddenChars) {
      if (note.contains(char)) {
        return char;
      }
    }
    return null;
  }
}
