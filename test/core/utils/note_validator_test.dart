import 'package:bb_mobile/core/utils/note_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoteValidator.validate', () {
    test('accepts a normal note', () {
      expect(NoteValidator.validate('lunch money'), isNull);
    });

    test('accepts an empty note — clearing a note is how you delete it', () {
      expect(NoteValidator.validate(''), isNull);
      expect(NoteValidator.validate('   '), isNull);
    });

    test('measures length on the TRIMMED note: surrounding whitespace is not '
        "the user's mistake", () {
      final exactly = 'a' * NoteValidator.maxNoteLength;

      expect(NoteValidator.validate(exactly), isNull);
      expect(NoteValidator.validate('   $exactly   '), isNull);
    });

    test('reports the limit when too long, so the message can name it', () {
      final tooLong = 'a' * (NoteValidator.maxNoteLength + 13);

      final violation = NoteValidator.validate(tooLong)! as NoteTooLong;

      expect(violation.maxLength, NoteValidator.maxNoteLength);
    });

    test('looks for forbidden characters in the RAW note, so a leading tab is '
        'still caught even though trimming would hide it', () {
      final violation = NoteValidator.validate('\tlunch');

      expect(violation, isA<NoteForbiddenCharacter>());
      expect((violation! as NoteForbiddenCharacter).character, '\t');
    });

    test('reports which character is forbidden, since it is the user\'s own '
        'input and safe to show back', () {
      final violation =
          NoteValidator.validate('a/b')! as NoteForbiddenCharacter;

      expect(violation.character, '/');
    });

    test('checks length before forbidden characters', () {
      // Both rules broken; the length one wins, matching the original order.
      final violation = NoteValidator.validate('${'a' * 60}/');

      expect(violation, isA<NoteTooLong>());
    });

    test('carries structured data, not an English sentence — returning one '
        'here is what painted untranslated text on the note sheet', () {
      final forbidden = NoteValidator.validate('a/b')!;
      final tooLong = NoteValidator.validate('a' * 60)!;

      // The exact strings NoteValidator used to hand to the UI.
      expect(forbidden.toString(), isNot(contains('contains forbidden')));
      expect(tooLong.toString(), isNot(contains('must be no more than')));
    });
  });
}
