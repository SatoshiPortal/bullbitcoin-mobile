/// Brightness-invariant corner-radius scale (px).
///
/// A fixed design-system scale — radii never scale with screen size.
abstract final class BullRadius {
  /// No rounding.
  static const double zero = 0;

  /// Hairline — buttons, cards, badges, checkbox (the design's 2px
  /// `--r-button`/`--r-card`).
  static const double xxs = 2;

  /// Extra-small — sheets segments, small chips, inputs.
  static const double xs = 4;

  /// Small.
  static const double sm = 8;

  /// Medium.
  static const double md = 12;

  /// Large — bottom-sheet top corners.
  static const double lg = 16;

  /// Extra-large.
  static const double xl = 28;

  /// 2x extra-large.
  static const double xxl = 32;

  /// Fully rounded — pills and grabbers.
  static const double full = 999;
}

/// Brightness-invariant spacing scale (px).
///
/// A fixed design-system scale — spacing never scales with screen size.
abstract final class BullSpacing {
  static const double zero = 0;
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}
