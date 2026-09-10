import 'package:bb_mobile/core/failures/failure.dart';

/// Closed set of every failure the labels feature surfaces to the user.
/// `sealed` keeps it closed (exhaustive switches; no foreign variants). Pure
/// Dart — the user-facing message lives in the presentation extension
/// `label_failure_l10n.dart`, never here.
sealed class LabelFailure extends Failure {
  const LabelFailure([super.logMessage]);
}

/// The note is longer than a label may carry.
final class LabelNoteTooLongFailure extends LabelFailure {
  final int maxLength;

  const LabelNoteTooLongFailure({required this.maxLength, String? logMessage})
    : super(logMessage);
}

/// The note contains a character that cannot be carried in a BIP21 URI.
/// [character] is the user's own input, not an internal detail, so it is safe
/// to show back to them.
final class LabelNoteForbiddenCharacterFailure extends LabelFailure {
  final String character;

  const LabelNoteForbiddenCharacterFailure({
    required this.character,
    String? logMessage,
  }) : super(logMessage);
}

/// The chosen file is larger than the import limit.
final class LabelsFileTooLargeFailure extends LabelFailure {
  final int maxBytes;

  const LabelsFileTooLargeFailure({required this.maxBytes, String? logMessage})
    : super(logMessage);
}

/// The file is not a BIP-329 labels file, or is malformed.
final class LabelsFileUnreadableFailure extends LabelFailure {
  const LabelsFileUnreadableFailure([super.logMessage]);
}

/// The file parsed, but contains no labels.
final class LabelsFileEmptyFailure extends LabelFailure {
  const LabelsFileEmptyFailure([super.logMessage]);
}

/// The file is valid BIP-329, but an entry carries a reference the app
/// cannot accept — a txid that is not 64 hex characters, a malformed
/// `txid:vout` outpoint, or an invalid xpub.
final class LabelsFileInvalidEntryFailure extends LabelFailure {
  const LabelsFileInvalidEntryFailure([super.logMessage]);
}

/// The file uses a label name the app reserves for its own system labels.
/// Importing it would collide with labels the app manages itself.
final class LabelsFileReservedNameFailure extends LabelFailure {
  const LabelsFileReservedNameFailure([super.logMessage]);
}

/// Writing the export file failed. Distinct from the user cancelling the save
/// dialog, which is not a failure at all and is not reported.
final class LabelsExportFailure extends LabelFailure {
  const LabelsExportFailure([super.logMessage]);
}

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI —
/// the presentation extension returns the shared generic string.
final class LabelUnexpectedFailure extends LabelFailure {
  const LabelUnexpectedFailure([super.logMessage]);
}
