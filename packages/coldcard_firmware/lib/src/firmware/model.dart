/// Coldcard hardware models supported for firmware download.
///
/// Each model has its own downloads page and its own version space: Q firmware is versioned v1.x with a `Q` marker, the Mk4 line v5.x with none. Versions are therefore only ever compared within one model.
enum ColdcardModel {
  /// Coldcard Q. Files: `*-q1-coldcard.dfu`, version carries `Q` (e.g. v1.4.1Q).
  q(
    displayName: 'Coldcard Q',
    downloadsPagePath: 'q1',
    filenameSuffixes: {'q1'},
    requiresQMarker: true,
  ),

  /// Coldcard Mk4. Files: `*-mk-coldcard.dfu` since v5.5.0, `*-mk4-coldcard.dfu` before that.
  mk4(
    displayName: 'Coldcard Mk4',
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
