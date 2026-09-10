import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each [LabelFailure]. The `sealed` switch
/// makes a missing message a compile error. Never returns the raw `logMessage`.
extension LabelFailureL10n on LabelFailure {
  String toTranslated(BuildContext context) => switch (this) {
    LabelNoteTooLongFailure(:final maxLength) =>
      context.loc.labelsErrorNoteTooLong(maxLength),
    // Tabs, newlines and carriage returns are on the forbidden list, and
    //  interpolating one renders "…the character " followed by nothing. They
    //  get named instead of shown.
    LabelNoteForbiddenCharacterFailure(:final character) =>
      _isInvisible(character)
          ? context.loc.labelsErrorNoteForbiddenWhitespace
          : context.loc.labelsErrorNoteForbiddenCharacter(character),
    LabelsFileTooLargeFailure(:final maxBytes) =>
      context.loc.labelsErrorFileTooLarge(_humanBytes(maxBytes)),
    LabelsFileUnreadableFailure() => context.loc.labelsErrorFileUnreadable,
    LabelsFileEmptyFailure() => context.loc.labelsErrorFileEmpty,
    LabelsFileInvalidEntryFailure() => context.loc.labelsErrorFileInvalidEntry,
    LabelsFileReservedNameFailure() => context.loc.labelsErrorFileReservedName,
    LabelsExportFailure() => context.loc.labelsErrorExportFailed,
    LabelUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
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
