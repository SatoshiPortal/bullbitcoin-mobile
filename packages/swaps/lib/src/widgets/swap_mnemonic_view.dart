import 'package:flutter/widgets.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/swap_failure.dart';

/// Displays recovery words inside the swap owner without exposing them in the
/// widget tree or semantics. The host must protect the screen from capture.
final class SwapMnemonicView extends StatefulWidget {
  final Future<Result<String?, SwapsFailure>> Function() _readWords;
  final Object identity;
  final TextStyle style;
  final Widget failure;

  const SwapMnemonicView({
    super.key,
    required this._readWords,
    required this.identity,
    required this.style,
    required this.failure,
  });

  @override
  State<SwapMnemonicView> createState() => _SwapMnemonicViewState();
}

final class _SwapMnemonicViewState extends State<SwapMnemonicView> {
  String? _words;
  bool _loading = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(SwapMnemonicView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) {
      _read();
    }
  }

  Future<void> _read() async {
    final generation = ++_generation;
    _words = null;
    _loading = true;
    final result = await widget._readWords();
    if (!mounted || generation != _generation) return;
    setState(() {
      _loading = false;
      _words = switch (result) {
        Ok(:final value) => value,
        Err() => null,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 20);
    final words = _words;
    if (words == null || words.isEmpty) return widget.failure;
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final direction = Directionality.of(context);
          final scaler =
              MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
          final textPainter = TextPainter(
            text: TextSpan(text: words, style: widget.style),
            textDirection: direction,
            textScaler: scaler,
          )..layout(maxWidth: constraints.maxWidth);
          final height = textPainter.height;
          textPainter.dispose();
          return CustomPaint(
            painter: _MnemonicPainter(words, widget.style, direction, scaler),
            size: Size(constraints.maxWidth, height),
          );
        },
      ),
    );
  }
}

final class _MnemonicPainter extends CustomPainter {
  final String _words;
  final TextStyle _style;
  final TextDirection _direction;
  final TextScaler _scaler;

  _MnemonicPainter(this._words, this._style, this._direction, this._scaler);

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(text: _words, style: _style),
      textDirection: _direction,
      textScaler: _scaler,
    )..layout(maxWidth: size.width);
    painter.paint(canvas, Offset.zero);
    painter.dispose();
  }

  @override
  bool shouldRepaint(_MnemonicPainter oldDelegate) =>
      _words != oldDelegate._words ||
      _style != oldDelegate._style ||
      _direction != oldDelegate._direction ||
      _scaler != oldDelegate._scaler;
}
