import 'package:flutter/widgets.dart';
import 'package:labels/labels.dart';

import '../label_editor_l10n.dart';

/// User-facing, localized message for each [LabelFailure]. The `sealed` switch
/// makes a missing message a compile error. Never returns the raw `logMessage`.
extension LabelFailureL10n on LabelFailure {
  String toTranslated(BuildContext context) => switch (this) {
    LabelNoteTooLongFailure(:final maxLength) =>
      context.labelLoc.labelsErrorNoteTooLong(maxLength),
    // Tabs, newlines and carriage returns are on the forbidden list, and
    //  interpolating one renders "…the character " followed by nothing. They
    //  get named instead of shown.
    LabelNoteForbiddenCharacterFailure(:final character) =>
      _isInvisible(character)
          ? context.labelLoc.labelsErrorNoteForbiddenWhitespace
          : context.labelLoc.labelsErrorNoteForbiddenCharacter(character),
    LabelsFileTooLargeFailure(:final maxBytes) =>
      context.labelLoc.labelsErrorFileTooLarge(_humanBytes(maxBytes)),
    LabelsFileUnreadableFailure() => context.labelLoc.labelsErrorFileUnreadable,
    LabelsFileEmptyFailure() => context.labelLoc.labelsErrorFileEmpty,
    LabelsFileInvalidEntryFailure() =>
      context.labelLoc.labelsErrorFileInvalidEntry,
    LabelsFileReservedNameFailure() =>
      context.labelLoc.labelsErrorFileReservedName,
    LabelsExportFailure() => context.labelLoc.labelsErrorExportFailed,
    LabelUnexpectedFailure() ||
    LabelsStorageNotReadyFailure() => context.labelLoc.oopsSomethingWentWrong,
  };

  bool _isInvisible(String character) =>
      character.trim().isEmpty ||
      character.codeUnits.every((c) => c < 0x20 || c == 0x7F);

  /// Formatted here rather than in the failure: a byte count is data, and how
  /// to render it is a presentation decision.
  ///
  /// Only whole MiB are rendered with a unit, because "MiB" is the only unit
  /// that appears in no translation file. A limit that is not a whole MiB
  /// falls back to the bare number rather than inventing English inside an
  /// otherwise translated sentence — and the assert fires first in debug, so
  /// whoever changes the limit adds the unit as a localized key instead.
  String _humanBytes(int bytes) {
    const mib = 1024 * 1024;
    if (bytes >= mib && bytes % mib == 0) return '${bytes ~/ mib} MiB';
    assert(
      false,
      'Import limit is no longer a whole MiB: add a localized unit key '
      'rather than hardcoding one here.',
    );
    return '$bytes';
  }
}
