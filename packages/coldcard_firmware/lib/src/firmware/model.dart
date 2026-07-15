/// Coldcard hardware models supported for firmware download.
///
/// Each model has its own downloads page and its own version space: Q firmware is versioned v1.x with a `Q` marker, the MK line v5.x with none. Versions are therefore only ever compared within one model.
enum ColdcardModel {
  /// Coldcard Q. Files: `*-q1-coldcard.dfu`, version carries `Q` (e.g. v1.4.1Q).
  q(
    displayName: 'Q',
    downloadsPagePath: 'q1',
    filenameSuffixes: {'q1'},
    requiresQMarker: true,
  ),

  /// The Coldcard MK line: Mk5 and Mk4 share one firmware image (coldcard.com lists them as "Mk5/Mk4"). Files: `*-mk-coldcard.dfu` since v5.5.0, `*-mk4-coldcard.dfu` before that.
  mk4(
    displayName: 'MK',
    downloadsPagePath: 'mk',
    filenameSuffixes: {'mk', 'mk4'},
    requiresQMarker: false,
  );

  const ColdcardModel({
    required this.displayName,
    required this.downloadsPagePath,
    required this.filenameSuffixes,
    required this.requiresQMarker,
  });

  final String displayName;

  /// Path segment of the model's page under `https://coldcard.com/downloads/`.
  final String downloadsPagePath;

  /// Model suffixes this hardware accepts in release filenames.
  final Set<String> filenameSuffixes;

  /// Whether release versions for this model carry the `Q` marker.
  final bool requiresQMarker;
}
