import 'package:material_ui/material_ui.dart';

/// The colours of the on-screen keypads (mnemonic keyboard, PIN pad), injected by the app as a [ThemeExtension] next to [BullTheme].
///
/// Components read them through [BullKeypadColorsX.bullKeypad]. [light] and [dark] hold Bull's values, chosen so that each pair a user reads (glyph on key, key on panel) has the same WCAG contrast in both themes. The active state keeps [BullTheme]'s primary and onPrimary.
@immutable
class BullKeypadColors extends ThemeExtension<BullKeypadColors> {
  /// The panel behind the keys.
  final Color panel;

  /// A letter or digit key.
  final Color key;

  /// The glyph of a [key].
  final Color onKey;

  /// Backspace, enter, scramble, page and language keys.
  final Color functionKey;

  /// The glyph of an enabled [functionKey].
  final Color onFunctionKey;

  /// The glyph of a disabled [functionKey].
  final Color onFunctionKeyDisabled;

  /// The glyph of a disabled letter or digit key, which has no fill and sinks into the [panel].
  final Color disabledGlyph;

  const BullKeypadColors({
    required this.panel,
    required this.key,
    required this.onKey,
    required this.functionKey,
    required this.onFunctionKey,
    required this.onFunctionKeyDisabled,
    required this.disabledGlyph,
  });

  /// Bull's keypad on a light theme.
  static const light = BullKeypadColors(
    panel: Color(0xFFBBBBBB),
    key: Color(0xFFFFFFFF),
    onKey: Color(0xFF000000),
    functionKey: Color(0xFF969696),
    onFunctionKey: Color(0xFF000000),
    onFunctionKeyDisabled: Color(0xFF5E5E5E),
    disabledGlyph: Color(0xFF969696),
  );

  /// Bull's keypad on a dark theme.
  static const dark = BullKeypadColors(
    panel: Color(0xFF3C3C3E),
    key: Color(0xFF000000),
    onKey: Color(0xFFFFFFFF),
    functionKey: Color(0xFF58585A),
    onFunctionKey: Color(0xFFFFFFFF),
    onFunctionKeyDisabled: Color(0xFF8E8E93),
    disabledGlyph: Color(0xFF58585A),
  );

  /// [light] or [dark] for [brightness].
  static BullKeypadColors of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  @override
  BullKeypadColors copyWith({
    Color? panel,
    Color? key,
    Color? onKey,
    Color? functionKey,
    Color? onFunctionKey,
    Color? onFunctionKeyDisabled,
    Color? disabledGlyph,
  }) {
    return BullKeypadColors(
      panel: panel ?? this.panel,
      key: key ?? this.key,
      onKey: onKey ?? this.onKey,
      functionKey: functionKey ?? this.functionKey,
      onFunctionKey: onFunctionKey ?? this.onFunctionKey,
      onFunctionKeyDisabled:
          onFunctionKeyDisabled ?? this.onFunctionKeyDisabled,
      disabledGlyph: disabledGlyph ?? this.disabledGlyph,
    );
  }

  @override
  BullKeypadColors lerp(
    covariant ThemeExtension<BullKeypadColors>? other,
    double t,
  ) {
    if (other is! BullKeypadColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return BullKeypadColors(
      panel: mix(panel, other.panel),
      key: mix(key, other.key),
      onKey: mix(onKey, other.onKey),
      functionKey: mix(functionKey, other.functionKey),
      onFunctionKey: mix(onFunctionKey, other.onFunctionKey),
      onFunctionKeyDisabled: mix(
        onFunctionKeyDisabled,
        other.onFunctionKeyDisabled,
      ),
      disabledGlyph: mix(disabledGlyph, other.disabledGlyph),
    );
  }
}

/// Accessor for the injected [BullKeypadColors] off any [BuildContext].
extension BullKeypadColorsX on BuildContext {
  /// The active [BullKeypadColors]. Throws a [StateError] if the app did not register one in its `ThemeData.extensions`.
  BullKeypadColors get bullKeypad {
    final keypad = Theme.of(this).extension<BullKeypadColors>();
    if (keypad == null) {
      throw StateError(
        'No BullKeypadColors registered: add BullKeypadColors.of(brightness) to ThemeData.extensions.',
      );
    }
    return keypad;
  }
}
