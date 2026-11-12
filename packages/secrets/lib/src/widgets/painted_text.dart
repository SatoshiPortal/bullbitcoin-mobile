import 'dart:math' as math;

import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Language;
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// One mnemonic word painted without a string-bearing widget in the tree.
final class PaintedWord extends _PaintedText {
  @internal
  PaintedWord(
    String word, {
    Language language = Language.english,
    super.style,
    super.key,
  }) : super([word], _Cell.word, language: language, plain: word);
}

/// A passphrase painted without exposing its text to the host.
///
/// Shaped as one paragraph inside a box sized only from its rune count.
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
  PaintedMnemonic(
    List<String> words, {
    Language language = Language.english,
    super.style,
    super.key,
  }) : super(
         List.of(words),
         _Cell.word,
         language: language,
         plain: words.join(language.separator),
       );
}

/// Secret text shares one private renderer. The host can place its widget but cannot read its text; screenshot protection belongs to the host screen.
///
/// Layout and intrinsic sizes use public cell metrics and a cell count only. Mnemonic words occupy fixed cells sized from the widest NFKD word in their BIP39 wordlist; passphrases are shaped privately within the same length-based box.
abstract class _PaintedText extends LeafRenderObjectWidget {
  final List<String> _cells;
  final _Cell _kind;
  final Language _language;
  final String _plain;
  final TextStyle? _style;

  const _PaintedText(
    this._cells,
    this._kind, {
    required this._plain,
    this._language = Language.english,
    this._style,
    super.key,
  });

  TextStyle _effectiveStyle(BuildContext context) =>
      DefaultTextStyle.of(context).style.merge(_style);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPaintedText(
    _cells,
    _kind,
    _language,
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
      _language,
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
  Iterable<String> templates(Language language) => switch (this) {
    // bip39's wordlists are NFKD already (pinned by seed_pbkdf2_test.dart).
    _Cell.word => language.list,
    _Cell.character => [
      for (var code = 0x21; code <= 0x7e; code++) String.fromCharCode(code),
    ],
  };
}

/// One cell's size and the gap after it, for a style.
typedef _Metrics = ({double width, double height, double gap});

final _metricsCache =
    <(_Cell, Language, TextStyle, TextDirection, TextScaler), _Metrics>{};

_Metrics _metricsOf(
  _Cell kind,
  Language language,
  TextStyle style,
  TextDirection direction,
  TextScaler scaler,
) => _metricsCache.putIfAbsent((kind, language, style, direction, scaler), () {
  final painter = TextPainter(textDirection: direction, textScaler: scaler);
  try {
    var width = 0.0;
    var height = 0.0;
    for (final text in kind.templates(language)) {
      painter
        ..text = TextSpan(text: text, style: style)
        ..layout();
      if (painter.width > width) width = painter.width;
      if (painter.height > height) height = painter.height;
    }
    var gap = 0.0;
    if (kind == _Cell.word) {
      painter
        ..text = TextSpan(text: language.separator, style: style)
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
  late Language _language;
  late int _cellCount;
  late String _plain;
  late TextStyle _style;
  late TextDirection _direction;
  late TextScaler _scaler;

  _RenderPaintedText(
    List<String> cells,
    _Cell kind,
    Language language,
    String plain,
    TextStyle style,
    TextDirection direction,
    TextScaler scaler,
  ) {
    _set(cells, kind, language, plain, style, direction, scaler);
  }

  void _set(
    List<String> cells,
    _Cell kind,
    Language language,
    String plain,
    TextStyle style,
    TextDirection direction,
    TextScaler scaler,
  ) {
    for (final painter in _painters) {
      painter.dispose();
    }
    _kind = kind;
    _language = language;
    _cellCount = cells.length;
    _plain = plain;
    _style = style;
    _direction = direction;
    _scaler = scaler;
    _painters = [
      for (final cell in kind == _Cell.character ? [plain] : cells)
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
    Language language,
    String plain,
    TextStyle style,
    TextDirection direction,
    TextScaler scaler,
  ) {
    if (_plain == plain &&
        _kind == kind &&
        _language == language &&
        _style == style &&
        _direction == direction &&
        _scaler == scaler &&
        _cellCount == cells.length) {
      return;
    }
    _set(cells, kind, language, plain, style, direction, scaler);
    markNeedsLayout();
  }

  _Metrics get _metrics =>
      _metricsOf(_kind, _language, _style, _direction, _scaler);

  int get _count => _cellCount;

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
    if (_kind == _Cell.character) {
      _painters.single.layout(maxWidth: size.width);
    }
  }

  // Like RenderParagraph: the text is a hit target, so a host's
  // GestureDetector around a tile still receives the tap.
  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_count == 0 || size.isEmpty) return;
    if (_kind == _Cell.character) {
      final painter = _painters.single;
      final width = painter.computeLineMetrics().fold(
        0.0,
        (width, line) => math.max(width, line.width),
      );
      // Shape the whole passphrase, but keep its layout independent of it.
      final scale = math.min(
        1.0,
        math.min(
          size.width / math.max(1.0, width),
          size.height / math.max(1.0, painter.height),
        ),
      );
      final x = _direction == TextDirection.rtl
          ? size.width - painter.width * scale
          : 0.0;
      final canvas = context.canvas;
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.clipRect(Offset.zero & size);
      canvas.translate(x, 0);
      canvas.scale(scale);
      painter.paint(canvas, Offset.zero);
      canvas.restore();
      return;
    }
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
