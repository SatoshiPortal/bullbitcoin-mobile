import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Language;
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// One mnemonic word painted without a string-bearing widget in the tree.
final class PaintedWord extends _PaintedText {
  @internal
  PaintedWord(String word, {super.style, super.key})
    : super([word], _Cell.word, plain: word);
}

/// A passphrase painted without exposing its text to the host.
///
/// One cell per character, so its length shows and its characters do not.
final class PaintedPassphrase extends _PaintedText {
  @internal
  PaintedPassphrase(String passphrase, {super.style, super.key})
    : super(
        [for (final rune in passphrase.runes) String.fromCharCode(rune)],
        _Cell.character,
        plain: passphrase,
      );
}

/// A complete mnemonic painted as a grid of words, without exposing its words to the host.
final class PaintedMnemonic extends _PaintedText {
  @internal
  PaintedMnemonic(List<String> words, {super.style, super.key})
    : super(List.of(words), _Cell.word, plain: words.join(' '));
}

/// Secret text shares one private renderer. The host can place its widget but cannot read its text; screenshot protection belongs to the host screen.
///
/// Every cell has the same size, set by public text alone (the widest BIP39 word, or the widest printable ASCII character, in the style), so neither the layout nor the intrinsic sizes a host can measure depend on the secret.
abstract class _PaintedText extends LeafRenderObjectWidget {
  final List<String> _cells;
  final _Cell _kind;
  final String _plain;
  final TextStyle? _style;

  const _PaintedText(
    this._cells,
    this._kind, {
    required this._plain,
    this._style,
    super.key,
  });

  TextStyle _effectiveStyle(BuildContext context) =>
      DefaultTextStyle.of(context).style.merge(_style);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPaintedText(
    _cells,
    _kind,
    _plain,
    _effectiveStyle(context),
    Directionality.maybeOf(context) ?? TextDirection.ltr,
    MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
  );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderPaintedText).update(
      _cells,
      _kind,
      _plain,
      _effectiveStyle(context),
      Directionality.maybeOf(context) ?? TextDirection.ltr,
      MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
    );
  }
}

enum _Cell {
  word,
  character;

  /// The public text a cell must hold, whatever the secret puts in it.
  Iterable<String> get templates => switch (this) {
    _Cell.word => Language.english.list,
    _Cell.character => [
      for (var code = 0x21; code <= 0x7e; code++) String.fromCharCode(code),
    ],
  };
}

/// One cell's size and the gap after it, for a style.
typedef _Metrics = ({double width, double height, double gap});

final _metricsCache =
    <(_Cell, TextStyle, TextDirection, TextScaler), _Metrics>{};

_Metrics _metricsOf(
  _Cell kind,
  TextStyle style,
  TextDirection direction,
  TextScaler scaler,
) => _metricsCache.putIfAbsent((kind, style, direction, scaler), () {
  final painter = TextPainter(textDirection: direction, textScaler: scaler);
  try {
    var width = 0.0;
    var height = 0.0;
    for (final text in kind.templates) {
      painter
        ..text = TextSpan(text: text, style: style)
        ..layout();
      if (painter.width > width) width = painter.width;
      if (painter.height > height) height = painter.height;
    }
    var gap = 0.0;
    if (kind == _Cell.word) {
      painter
        ..text = TextSpan(text: ' ', style: style)
        ..layout();
      gap = painter.width;
    }
    return (width: width, height: height, gap: gap);
  } finally {
    painter.dispose();
  }
});

/// The painted cells, as a render box that sizes, wraps and reports intrinsics from the cell metrics alone, and receives taps like `RenderParagraph`, without a string anywhere a host can reach.
final class _RenderPaintedText extends RenderBox {
  List<TextPainter> _painters = const [];
  late _Cell _kind;
  late String _plain;
  late TextStyle _style;
  late TextDirection _direction;
  late TextScaler _scaler;

  _RenderPaintedText(
    List<String> cells,
    _Cell kind,
    String plain,
    TextStyle style,
    TextDirection direction,
    TextScaler scaler,
  ) {
    _set(cells, kind, plain, style, direction, scaler);
  }

  void _set(
    List<String> cells,
    _Cell kind,
    String plain,
    TextStyle style,
    TextDirection direction,
    TextScaler scaler,
  ) {
    for (final painter in _painters) {
      painter.dispose();
    }
    _kind = kind;
    _plain = plain;
    _style = style;
    _direction = direction;
    _scaler = scaler;
    _painters = [
      for (final cell in cells)
        TextPainter(
          text: TextSpan(text: cell, style: style),
          textDirection: direction,
          textScaler: scaler,
        )..layout(),
    ];
  }

  void update(
    List<String> cells,
    _Cell kind,
    String plain,
    TextStyle style,
    TextDirection direction,
    TextScaler scaler,
  ) {
    if (_plain == plain &&
        _kind == kind &&
        _style == style &&
        _direction == direction &&
        _scaler == scaler &&
        _painters.length == cells.length) {
      return;
    }
    _set(cells, kind, plain, style, direction, scaler);
    markNeedsLayout();
  }

  _Metrics get _metrics => _metricsOf(_kind, _style, _direction, _scaler);

  int get _count => _painters.length;

  /// How many cells fit on a line of [maxWidth]: at least one, at most all.
  int _perLine(double maxWidth) {
    final m = _metrics;
    if (_count == 0) return 1;
    if (!maxWidth.isFinite) return _count;
    final fit = ((maxWidth + m.gap) / (m.width + m.gap)).floor();
    return fit.clamp(1, _count);
  }

  Size _sizeFor(double maxWidth) {
    final m = _metrics;
    if (_count == 0) return Size.zero;
    final columns = _perLine(maxWidth);
    final lines = (_count / columns).ceil();
    return Size(columns * m.width + (columns - 1) * m.gap, lines * m.height);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _count == 0 ? 0 : _metrics.width;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _sizeFor(double.infinity).width;

  @override
  double computeMinIntrinsicHeight(double width) => _sizeFor(width).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.constrain(_sizeFor(constraints.maxWidth));

  @override
  void performLayout() {
    size = constraints.constrain(_sizeFor(constraints.maxWidth));
  }

  // Like RenderParagraph: the text is a hit target, so a host's
  // GestureDetector around a tile still receives the tap.
  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final m = _metrics;
    final columns = _perLine(size.width);
    for (var i = 0; i < _painters.length; i++) {
      final column = i % columns;
      final x = _direction == TextDirection.rtl
          ? size.width - (column + 1) * m.width - column * m.gap
          : column * (m.width + m.gap);
      _painters[i].paint(
        context.canvas,
        offset + Offset(x, (i ~/ columns) * m.height),
      );
    }
  }

  @override
  void dispose() {
    for (final painter in _painters) {
      painter.dispose();
    }
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
  return render is _RenderPaintedText ? render._plain : null;
}
