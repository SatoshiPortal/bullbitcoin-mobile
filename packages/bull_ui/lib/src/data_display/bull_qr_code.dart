import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/bull_theme.dart';

/// Exact public request rendering; parsing, copying and sharing belong to callers.
final class BullQrCode extends StatelessWidget {
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final side = math.min(size, math.min(bounds.maxWidth, bounds.maxHeight));
      Widget unavailable() => Align(
        child: SizedBox.square(
          dimension: side,
          child: errorBuilder?.call(context),
        ),
      );
      if (data.isEmpty) return unavailable();
      final validated = QrValidator.validate(data: data);
      final qr = validated.qrCode;
      if (!validated.isValid || qr == null) return unavailable();
      try {
        QrImage.withMaskPattern(qr, 0);
      } on InputTooLongException {
        return unavailable();
      }
      // Match the pinned painter's half-logical-pixel module rounding without
      // expanding beyond the available square or consuming the quiet zone.
      final step = (2 * side / (qr.moduleCount + 8)).floor() / 2;
      if (step <= 0) return unavailable();
      final total = (qr.moduleCount + 8) * step;
      final colors = context.bull;
      final image = ExcludeSemantics(
        child: QrImageView.withQr(
          qr: qr,
          size: total,
          padding: EdgeInsets.all(4 * step),
          gapless: true,
          backgroundColor: colors.onSecondaryFixed,
          semanticsLabel: '',
          eyeStyle: QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: colors.onSurfaceFixed,
          ),
          dataModuleStyle: QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: colors.onSurfaceFixed,
          ),
        ),
      );
      final label = semanticsLabel;
      return Align(
        child: SizedBox.square(
          dimension: total,
          child: label == null
              ? image
              : Semantics(image: true, label: label, child: image),
        ),
      );
    },
  );
}
