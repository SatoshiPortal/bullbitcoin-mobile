import 'package:flutter/widgets.dart';

/// Brightness-invariant corner radii (px), per the design spec (§14).
abstract final class BullRadius {
  /// Buttons and cards.
  static const double button = 2;

  /// Cards (alias of [button]).
  static const double card = 2;

  /// Small chips / tool buttons.
  static const double small = 4;

  /// Bottom-sheet top corners.
  static const double sheet = 16;

  /// Pills and grabbers (fully rounded).
  static const double pill = 100;
}

/// Brightness-invariant spacing scale (px).
abstract final class BullSpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 11;
  static const double l = 14;
  static const double xl = 16;
}

/// Typed text styles over the Golos Text family, the type used throughout these
/// screens (Bebas Neue is hero-only and unused here). Brightness-invariant —
/// colour is applied at the call site via `context.bull`.
abstract final class BullTextStyles {
  static const String _family = 'Golos Text';

  /// Amount line — 15.5/w600, tabular figures.
  static const TextStyle amount = TextStyle(
    fontFamily: _family,
    fontSize: 15.5,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Title — 16/w600.
  static const TextStyle title = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  /// Bold value — 15/w700, tabular figures (summary stat value).
  static const TextStyle statValue = TextStyle(
    fontFamily: _family,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Body — 14/w400.
  static const TextStyle body = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  /// Body emphasis — 13.5/w600.
  static const TextStyle bodyEmphasis = TextStyle(
    fontFamily: _family,
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
  );

  /// Secondary — 13.5/w400.
  static const TextStyle secondary = TextStyle(
    fontFamily: _family,
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
  );

  /// Label — 12/w400.
  static const TextStyle label = TextStyle(
    fontFamily: _family,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  /// Pill / badge text — 11/w600.
  static const TextStyle pill = TextStyle(
    fontFamily: _family,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  /// Uppercase badge — 10.5/w600.
  static const TextStyle badge = TextStyle(
    fontFamily: _family,
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
  );

  /// Caption — 11/w400.
  static const TextStyle caption = TextStyle(
    fontFamily: _family,
    fontSize: 11,
    fontWeight: FontWeight.w400,
  );
}
