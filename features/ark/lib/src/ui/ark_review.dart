import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/painting.dart' show TextPainter;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

// Ark's confirm screens, built from the same bull_ui pieces as the app's own
// send confirmation: its header, and label/value rows between thin lines.

/// What is being confirmed: the arrow in its circle, the title, the amount.
class ArkReviewHeader extends StatelessWidget {
  final String title;
  final String amount;

  /// The app's confirmation arrow; bull_ui's arrow without it.
  final Widget? icon;

  const ArkReviewHeader({
    super.key,
    required this.title,
    required this.amount,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: BullConfirmationHeader(
      title: title,
      amount: amount,
      icon:
          icon ??
          BullIcon(
            BullIcons.arrowUpward,
            size: 24,
            color: context.bull.secondary,
          ),
    ),
  );
}

/// The confirmation's rows, each followed by a thin line, as in the app.
class ArkReviewFacts extends StatelessWidget {
  final List<Widget> children;

  const ArkReviewFacts({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (index, child) in children.indexed) ...[
        if (index > 0)
          Container(height: 1, color: context.bull.secondaryFixedDim),
        child,
      ],
      Container(height: 1, color: context.bull.secondaryFixedDim),
    ],
  );
}

/// One row: a muted label left, the value right, in the app's styles.
class ArkReviewFact extends StatelessWidget {
  final String label;
  final String value;

  /// A smaller line under the value, such as its fiat equivalent.
  final String? detail;

  const ArkReviewFact({
    super.key,
    required this.label,
    required this.value,
    this.detail,
  });

  @override
  Widget build(BuildContext context) => BullConfirmationRow(
    title: label,
    details: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        BullText(
          value,
          style: context.bullType.body
              .copyWith(fontWeight: FontWeight.w500)
              .copyWith(color: context.bull.secondary),
          textAlign: TextAlign.end,
        ),
        if (detail case final text?)
          BullText(
            text,
            style: context.bullType.caption.copyWith(
              color: context.bull.secondary,
            ),
            textAlign: TextAlign.end,
          ),
      ],
    ),
  );
}

/// The recipient row, as the app shows an address: one line, shortened in
/// the middle to fit, dotted underline. A long press copies it whole.
class ArkReviewAddress extends StatelessWidget {
  final String label;
  final String address;
  final String copiedMessage;

  const ArkReviewAddress({
    super.key,
    required this.label,
    required this.address,
    required this.copiedMessage,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.bull.secondary;
    final style = context.bullType.body
        .copyWith(fontWeight: FontWeight.w500)
        .copyWith(
          color: color,
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dotted,
          decorationColor: color.withAlpha(120),
        );
    void copy() {
      Clipboard.setData(ClipboardData(text: address));
      BullSnackBar.show(context, message: copiedMessage);
    }

    return BullConfirmationRow(
      title: label,
      verticalPadding: 0,
      details: Semantics(
        label: address,
        excludeSemantics: true,
        onLongPress: copy,
        child: GestureDetector(
          onLongPress: copy,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: LayoutBuilder(
              builder: (context, constraints) => Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _fit(address, style, constraints.maxWidth),
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.end,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The longest middle-shortened form that fits [width] at [style].
  static String _fit(String text, TextStyle style, double width) {
    if (text.isEmpty || _width(text, style) <= width) return text;
    const minSide = 5;
    if (text.length <= minSide * 2) return text;
    for (var side = (text.length - 1) ~/ 2; side >= minSide; side--) {
      final shortened =
          '${text.substring(0, side)}…${text.substring(text.length - side)}';
      if (_width(shortened, style) <= width) return shortened;
    }
    return '${text.substring(0, minSide)}…${text.substring(text.length - minSide)}';
  }

  static double _width(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}
