import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/bull_theme.dart';

/// Exact public request rendering; parsing, copying and sharing belong to callers.
final class BullQrCode extends StatefulWidget {
  final String data;
  final double size;
  final String? semanticsLabel;
  final WidgetBuilder? errorBuilder;

  const BullQrCode({
    super.key,
    required this.data,
    required this.size,
    this.semanticsLabel,
    this.errorBuilder,
  }) : assert(size > 0 && size < double.infinity);

  @override
  State<BullQrCode> createState() => _BullQrCodeState();
}

class _BullQrCodeState extends State<BullQrCode> {
  /// The payload the [QrCode] below was built from.
  String? _symbolData;

  /// The validated symbol for [_symbolData], or null when it was rejected.
  QrCode? _symbol;

  /// The symbol [._painter] was built for, compared by identity.
  QrCode? _painterSymbol;

  /// The foreground the cached painter was built with.
  Color? _painterForeground;

  /// `QrImage(qr)` tries all eight masks and keeps the one with the lowest
  /// penalty. `QrPainter` pays that search in its constructor, so anything that
  /// rebuilds this widget on a state emission pays it again for the same
  /// symbol: 1.4 ms for a 29-module address and 4.4 ms for a 45-module silent
  /// payment code, host median, `qr` 3.0.3. The painter only depends on the
  /// symbol, the module styles and the colours, never on the layout bounds, so
  /// it outlives a rebuild whose payload and theme are unchanged.
  QrPainter? _painter;

  QrCode? _validatedSymbol(String data) {
    if (_symbolData == data) return _symbol;
    _symbolData = data;
    final validated = QrValidator.validate(data: data);
    final qr = validated.qrCode;
    if (!validated.isValid || qr == null) {
      _symbol = null;
      return null;
    }
    try {
      // Reject a symbol the painter cannot expand before it reaches layout.
      QrImage.withMaskPattern(qr, 0);
    } on InputTooLongException {
      _symbol = null;
      return null;
    }
    _symbol = qr;
    return qr;
  }

  QrPainter _painterFor(QrCode symbol, Color foreground) {
    final cached = _painter;
    if (cached != null &&
        identical(_painterSymbol, symbol) &&
        _painterForeground == foreground) {
      return cached;
    }
    final painter = QrPainter.withQr(
      qr: symbol,
      gapless: true,
      eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: foreground),
      dataModuleStyle: QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: foreground,
      ),
    );
    _painterSymbol = symbol;
    _painterForeground = foreground;
    _painter = painter;
    return painter;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final side = math.min(
        widget.size,
        math.min(bounds.maxWidth, bounds.maxHeight),
      );
      Widget unavailable() => Align(
        child: SizedBox.square(
          dimension: side,
          child: widget.errorBuilder?.call(context),
        ),
      );
      if (widget.data.isEmpty) return unavailable();
      final qr = _validatedSymbol(widget.data);
      if (qr == null) return unavailable();
      // Match the pinned painter's half-logical-pixel module rounding without
      // expanding beyond the available square or consuming the quiet zone.
      final step = (2 * side / (qr.moduleCount + 8)).floor() / 2;
      if (step <= 0) return unavailable();
      final total = (qr.moduleCount + 8) * step;
      final colors = context.bull;
      final image = ExcludeSemantics(
        child: SizedBox.square(
          dimension: total,
          child: ColoredBox(
            color: colors.onSecondaryFixed,
            child: Padding(
              padding: EdgeInsets.all(4 * step),
              child: CustomPaint(
                painter: _painterFor(qr, colors.onSurfaceFixed),
              ),
            ),
          ),
        ),
      );
      final label = widget.semanticsLabel;
      return Align(
        child: label == null
            ? image
            : Semantics(image: true, label: label, child: image),
      );
    },
  );
}
