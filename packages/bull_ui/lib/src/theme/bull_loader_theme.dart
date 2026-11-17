import 'package:material_ui/material_ui.dart';

/// How a `BullLoader` animates.
enum BullLoaderStyle {
  /// Bull's looping cubes.
  cubes,

  /// A circular spinner in the primary colour.
  spinner,
}

/// The loader style the app picked; see `bullUiExtensions`.
class BullLoaderTheme extends ThemeExtension<BullLoaderTheme> {
  final BullLoaderStyle style;

  const BullLoaderTheme({required this.style});

  static const standard = BullLoaderTheme(style: BullLoaderStyle.cubes);

  @override
  BullLoaderTheme copyWith({BullLoaderStyle? style}) =>
      BullLoaderTheme(style: style ?? this.style);

  @override
  BullLoaderTheme lerp(BullLoaderTheme? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

/// Accessor for the injected [BullLoaderTheme] off any [BuildContext].
extension BullLoaderThemeX on BuildContext {
  /// The active [BullLoaderTheme]. Throws a [StateError] if the app did not register one in its `ThemeData.extensions`.
  BullLoaderTheme get bullLoader {
    final loader = Theme.of(this).extension<BullLoaderTheme>();
    if (loader == null) {
      throw StateError(
        'No BullLoaderTheme registered: add BullLoaderTheme.standard to ThemeData.extensions.',
      );
    }
    return loader;
  }
}
