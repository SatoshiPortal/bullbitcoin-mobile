import 'package:labels/labels.dart';

/// Lifts a broken note rule into this feature's failure family.
///
/// Its own file, mirroring `send/domain/swap_failure_to_send_failure.dart`:
/// cross-domain mapping is domain work, so it belongs neither in a widget nor
/// in the failure declaration itself.
LabelFailure mapNoteViolationToLabelFailure(NoteViolation violation) =>
    switch (violation) {
      NoteTooLong(:final maxLength) => LabelNoteTooLongFailure(
        maxLength: maxLength,
      ),
      NoteForbiddenCharacter(:final character) =>
        LabelNoteForbiddenCharacterFailure(character: character),
    };
