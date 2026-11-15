import 'package:flutter/widgets.dart';

/// Window widths at which a layout changes shape.
abstract final class BullBreakpoints {
  /// From this width a screen uses its desktop layout.
  static const double desktop = 1000;

  /// Widest a single-column page (a form, a list, a flow step) gets on a
  /// desktop window.
  static const double pageMaxWidth = 640;
}

extension BullLayoutX on BuildContext {
  /// Whether the enclosing window is wide enough for a desktop layout.
  bool get isDesktopLayout =>
      MediaQuery.sizeOf(this).width >= BullBreakpoints.desktop;
}
