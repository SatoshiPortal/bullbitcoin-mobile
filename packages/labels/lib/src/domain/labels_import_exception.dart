/// Why a labels file could not be imported.
///
/// Thrown infra, so `Exception` is the right shape — the use-case maps it
/// into `LabelFailure`, which is what the UI sees.
///
/// Lives in `domain/` rather than beside the BIP-329 codec so the application
/// layer can catch it without importing a `frameworks/` file. Any future
/// converter reached through `LabelsConverterPort` throws this same type, and
/// the port stays the only thing the use-case knows about.
enum LabelsImportProblem {
  /// The file is larger than the format allows.
  tooLarge,

  /// The file is not in the expected format, or is malformed.
  unreadable,

  /// The file parsed but holds no labels.
  empty,

  /// The file uses a label name the app reserves for its own system labels.
  reservedName,
}

class LabelsImportException implements Exception {
  final LabelsImportProblem problem;

  /// Only meaningful for [LabelsImportProblem.tooLarge]. Carried by the
  /// thrower so the failure can name the limit without the application layer
  /// knowing which converter ran, and therefore which limit applies.
  final int maxBytes;

  /// [maxBytes] is meaningless here, so [LabelsImportProblem.tooLarge] must
  /// use [LabelsImportException.tooLarge] instead — otherwise the failure
  /// renders a limit of zero.
  const LabelsImportException(this.problem)
    : maxBytes = 0,
      assert(
        problem != LabelsImportProblem.tooLarge,
        'use LabelsImportException.tooLarge to carry the limit',
      );

  const LabelsImportException.tooLarge(this.maxBytes)
    : problem = LabelsImportProblem.tooLarge;

  @override
  String toString() => 'LabelsImportException($problem)';
}
