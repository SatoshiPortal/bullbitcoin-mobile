import 'model.dart';
import 'release.dart';

/// A release filename decomposed into its parts.
///
/// Grammar, covering every name Coinkite has ever published (see the signatures.txt history in the test fixtures):
///
///     <YYYY-MM-DDTHHMM>-v<maj>.<min>.<patch>[Q][X][-<model>]-coldcard[-factory].dfu
///
/// - the model suffix is ABSENT on legacy releases (v3.x/v4.x, Mk1-Mk3 era) and is `mk3`, `mk4`, `mk` (Mk4 line since v5.5.0) or `q1` since;
/// - `Q` marks Q-model builds, `X` marks edge/experimental builds;
/// - `-factory` images include the bootloader and are never for end users.
final class ParsedFirmwareFilename {
  const ParsedFirmwareFilename({
    required this.filename,
    required this.timestampRaw,
    required this.version,
    required this.modelSuffix,
    required this.isEdge,
    required this.isFactory,
  });

  final String filename;
  final String timestampRaw;
  final FirmwareVersion version;

  /// `q1`, `mk`, `mk4`, `mk3`, or null on legacy (pre-Mk4) filenames.
  final String? modelSuffix;

  final bool isEdge;
  final bool isFactory;

  static final RegExp _pattern = RegExp(
    r'^(\d{4}-\d{2}-\d{2}T\d{4})' // timestamp
    r'-v(\d+)\.(\d+)\.(\d+)' // version
    r'(Q?)(X?)' // Q-model marker, edge marker
    r'(?:-(mk4|mk3|mk|q1))?' // model suffix (absent on legacy releases)
    r'-coldcard(-factory)?\.dfu$',
  );

  /// Returns null for anything that is not a firmware filename (changelog entries in the manifest, unrelated page links, hostile input, ...).
  static ParsedFirmwareFilename? tryParse(String filename) {
    final match = _pattern.firstMatch(filename);
    if (match == null) return null;
    // tryParse, not parse: a version component long enough to overflow (hostile page content) is "not a firmware filename", not an exception.
    final major = int.tryParse(match.group(2)!);
    final minor = int.tryParse(match.group(3)!);
    final patch = int.tryParse(match.group(4)!);
    if (major == null || minor == null || patch == null) return null;
    return ParsedFirmwareFilename(
      filename: filename,
      timestampRaw: match.group(1)!,
      version: FirmwareVersion(
        major,
        minor,
        patch,
        hasQMarker: match.group(5)!.isNotEmpty,
      ),
      modelSuffix: match.group(7),
      isEdge: match.group(6)!.isNotEmpty,
      isFactory: match.group(8) != null,
    );
  }

  /// Whether this file is installable on [model] via the normal user flow. Edge and factory builds never are; legacy no-suffix files belong to pre-Mk4 hardware and match no supported model.
  bool isOfferedFor(ColdcardModel model) {
    if (isEdge || isFactory) return false;
    final suffix = modelSuffix;
    if (suffix == null) return false;
    return model.filenameSuffixes.contains(suffix) &&
        version.hasQMarker == model.requiresQMarker;
  }
}
