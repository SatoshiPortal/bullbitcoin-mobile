import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// One mnemonic word painted without a string-bearing widget in the tree.
final class PaintedWord extends _PaintedText {
  @internal
  const PaintedWord(super.word, {super.style, super.key});
}

/// A passphrase painted without exposing its text to the host.
final class PaintedPassphrase extends _PaintedText {
  @internal
  const PaintedPassphrase(super.passphrase, {super.style, super.key});
}

/// A complete mnemonic painted as a sentence, without exposing its words to the host.
final class PaintedMnemonic extends _PaintedText {
  @internal
  PaintedMnemonic(List<String> words, {TextStyle? style, super.key})
    : super(words.join(' '), style: style);
}

/// Secret text shares one private renderer. The host can place its widget but cannot read its text; screenshot protection belongs to the host screen.
abstract class _PaintedText extends LeafRenderObjectWidget {
  final String _text;
  final TextStyle? _style;

  const _PaintedText(this._text, {this._style, super.key});

  TextSpan _span(BuildContext context) => TextSpan(
    text: _text,
    style: DefaultTextStyle.of(context).style.merge(_style),
  );

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPaintedText(
    _span(context),
    Directionality.maybeOf(context) ?? TextDirection.ltr,
    MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
  );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderPaintedText).update(
      _span(context),
      Directionality.maybeOf(context) ?? TextDirection.ltr,
      MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
    );
  }
}

/// The painted text, as a render box — so it sizes, wraps and reports intrinsics like `RenderParagraph`, and receives taps like it too, without a string anywhere a host can reach.
final class _RenderPaintedText extends RenderBox {
  final TextPainter _painter;

  _RenderPaintedText(TextSpan text, TextDirection direction, TextScaler scaler)
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

/// The text a painted element renders — for this package's own tests, which must check what is on screen without a `Text` to find.
///
/// Not exported and `@internal`: a host reaches it only by importing `src/`, which `implementation_imports` makes an error, and calling an internal member, which `invalid_use_of_internal_member` makes one too.
@internal
@visibleForTesting
String? debugPaintedTextOf(Element element) {
  final render = element.renderObject;
  return render is _RenderPaintedText ? render._painter.plainText : null;
}
