import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// Secret text — one word of a mnemonic, a whole sentence, or a passphrase — as a widget the host can place but not read.
///
/// What `MnemonicView.wordBuilder` and `MnemonicTile.word` hand out, and how both widgets render every secret string. The text is **painted**: a private render object lays it out with a [TextPainter] and draws it on the canvas, so no `Text`, `RichText` or string-bearing widget is ever in the tree. A host walking its own element tree finds this widget and its render object, and both keep the string in library-private fields that no other library can read, with or without `dynamic`. What leaves is pixels — a screenshot, or a rendered image read back — which is the host screen's capture protection to handle.
///
/// Laid out like a `Text`: the ambient [DefaultTextStyle] merged with the given style, the ambient [Directionality] and the user's text scale, wrapping to the width it is given. Not exported: this type is the seal, not part of the surface.
final class SealedWord extends LeafRenderObjectWidget {
  final String _word;
  final TextStyle? _style;

  @internal
  const SealedWord(this._word, {this._style, super.key});

  TextSpan _span(BuildContext context) => TextSpan(
    text: _word,
    style: DefaultTextStyle.of(context).style.merge(_style),
  );

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSealedText(
    _span(context),
    Directionality.maybeOf(context) ?? TextDirection.ltr,
    MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
  );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderSealedText).update(
      _span(context),
      Directionality.maybeOf(context) ?? TextDirection.ltr,
      MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
    );
  }
}

/// The painted text, as a render box — so it sizes, wraps and reports intrinsics like `RenderParagraph`, and receives taps like it too, without a string anywhere a host can reach.
final class _RenderSealedText extends RenderBox {
  final TextPainter _painter;

  _RenderSealedText(TextSpan text, TextDirection direction, TextScaler scaler)
    : _painter = TextPainter(
        text: text,
        textDirection: direction,
        textScaler: scaler,
      );

  void update(TextSpan text, TextDirection direction, TextScaler scaler) {
    if (_painter.text == text &&
        _painter.textDirection == direction &&
        _painter.textScaler == scaler) {
      return;
    }
    _painter
      ..text = text
      ..textDirection = direction
      ..textScaler = scaler;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    _painter.layout();
    return _painter.minIntrinsicWidth;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    _painter.layout();
    return _painter.maxIntrinsicWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    _painter.layout(maxWidth: width);
    return _painter.height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    _painter.layout(maxWidth: constraints.maxWidth);
    return constraints.constrain(_painter.size);
  }

  @override
  void performLayout() {
    _painter.layout(maxWidth: constraints.maxWidth);
    size = constraints.constrain(_painter.size);
  }

  // Like RenderParagraph: the text is a hit target, so a host's
  // GestureDetector around a tile still receives the tap.
  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) =>
      _painter.paint(context.canvas, offset);

  @override
  void dispose() {
    _painter.dispose();
    super.dispose();
  }
}

/// The text a [SealedWord] element paints — for this package's own tests, which must check what is on screen without a `Text` to find.
///
/// Not exported and `@internal`: a host reaches it only by importing `src/`, which `implementation_imports` makes an error, and calling an internal member, which `invalid_use_of_internal_member` makes one too.
@internal
@visibleForTesting
String? debugSealedTextOf(Element element) {
  final render = element.renderObject;
  return render is _RenderSealedText ? render._painter.plainText : null;
}
