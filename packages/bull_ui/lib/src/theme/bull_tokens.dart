/// Brightness-invariant component sizes (px).
abstract final class BullSizes {
  /// Minimum height shared by the cards stacked on a home screen: the quick
  /// action bar, a wallet card and the banners above them.
  static const double homeCard = 90;
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
