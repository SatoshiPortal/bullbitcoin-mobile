import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// The `bull_ui` corner radii, one per role, injected by the app as a [ThemeExtension] next to [BullTheme].
///
/// Components read a radius through [BullShapesX.bullShapes] (e.g. `context.bullShapes.card`). [standard] holds Bull's values.
///
/// Every corner in widget code reads a role.
@immutable
class BullShapes extends ThemeExtension<BullShapes> {
  /// Buttons, full-size and compact.
  final double button;

  /// Keyboard keys and small icon toggles, such as the mnemonic keyboard and the hide-amounts eye.
  final double key;

  /// Cards, tiles, panels, frames and bordered containers.
  final double card;

  /// Text fields, dropdowns and field-like boxes, at rest and focused.
  final double input;

  /// Checkbox boxes.
  final double checkbox;

  /// System tags and markers: status tags, Frozen, network and number tags, unit suffixes.
  final double badge;

  /// Labels a user creates and attaches, such as transaction and address labels.
  final double chip;

  /// Surfaces that appear over the screen: dialogs (all corners) and bottom sheets and panels (top corners).
  final double sheet;

  /// Circles and pills.
  final double dot;

  const BullShapes({
    required this.button,
    required this.key,
    required this.card,
    required this.input,
    required this.checkbox,
    required this.badge,
    required this.chip,
    required this.sheet,
    required this.dot,
  });

  /// Bull's corner radii in px.
  static const standard = BullShapes(
    button: 2,
    key: 6,
    card: 2,
    input: 4,
    checkbox: 2,
    badge: 2,
    chip: 2,
    sheet: 8,
    dot: 999,
  );

  @override
  BullShapes copyWith({
    double? button,
    double? key,
    double? card,
    double? input,
    double? checkbox,
    double? badge,
    double? chip,
    double? sheet,
    double? dot,
  }) {
    return BullShapes(
      button: button ?? this.button,
      key: key ?? this.key,
      card: card ?? this.card,
      input: input ?? this.input,
      checkbox: checkbox ?? this.checkbox,
      badge: badge ?? this.badge,
      chip: chip ?? this.chip,
      sheet: sheet ?? this.sheet,
      dot: dot ?? this.dot,
    );
  }

  @override
  BullShapes lerp(covariant ThemeExtension<BullShapes>? other, double t) {
    if (other is! BullShapes) return this;
    double mix(double a, double b) => lerpDouble(a, b, t) ?? a;
    return BullShapes(
      button: mix(button, other.button),
      key: mix(key, other.key),
      card: mix(card, other.card),
      input: mix(input, other.input),
      checkbox: mix(checkbox, other.checkbox),
      badge: mix(badge, other.badge),
      chip: mix(chip, other.chip),
      sheet: mix(sheet, other.sheet),
      dot: mix(dot, other.dot),
    );
  }
}

/// Accessor for the injected [BullShapes] off any [BuildContext].
extension BullShapesX on BuildContext {
  /// The active [BullShapes]. Throws a [StateError] if the app did not register one in its `ThemeData.extensions`.
  BullShapes get bullShapes {
    final shapes = Theme.of(this).extension<BullShapes>();
    if (shapes == null) {
      throw StateError(
        'No BullShapes registered: add BullShapes.standard (or a fork\'s '
        'own BullShapes) to ThemeData.extensions.',
      );
    }
    return shapes;
  }
}
