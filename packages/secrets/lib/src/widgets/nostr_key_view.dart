import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:qr/qr.dart';
import 'package:secrets/src/domain/domain.dart';
import 'package:secrets/src/public/secret.dart';
import 'package:secrets/src/widgets/painted_text.dart';

/// Sealed nsec display. The host owns warnings and screenshot protection.
final class NostrKeyView extends StatefulWidget {
  final Secret _secret;
  final int identity;
  final String publicKey;
  final Color qrForeground;
  final Color qrBackground;
  final TextStyle? style;
  final Widget placeholder;
  final Widget Function(
    BuildContext,
    Widget text,
    Widget qr,
    Future<void> Function() copy,
  )
  builder;
  final Widget Function(BuildContext, SecretFailure, VoidCallback retry)
  failureBuilder;

  @internal
  const NostrKeyView({
    super.key,
    required this._secret,
    required this.identity,
    required this.publicKey,
    required this.qrForeground,
    required this.qrBackground,
    required this.builder,
    required this.failureBuilder,
    this.style,
    this.placeholder = const SizedBox.shrink(),
  });

  @override
  State<NostrKeyView> createState() => _NostrKeyViewState();
}

final class _NostrKeyViewState extends State<NostrKeyView> {
  Result<String, SecretFailure>? _result;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(NostrKeyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget._secret.id != oldWidget._secret.id ||
        widget.identity != oldWidget.identity ||
        widget.publicKey != oldWidget.publicKey) {
      _read();
    }
  }

  void _read() {
    _result = null;
    final generation = ++_generation;
    widget._secret
        .nostrNsec(identity: widget.identity, publicKey: widget.publicKey)
        .then((result) {
          if (!mounted || generation != _generation) return;
          setState(() => _result = result);
        });
  }

  Future<void> _copy(int generation) async {
    if (!mounted || generation != _generation) return;
    if (_result case Ok(:final value)) {
      await Clipboard.setData(ClipboardData(text: value));
    }
  }

  @override
  Widget build(BuildContext context) {
    final generation = _generation;
    return switch (_result) {
      null => widget.placeholder,
      Err(:final failure) => widget.failureBuilder(
        context,
        failure,
        () => setState(_read),
      ),
      Ok(:final value) => widget.builder(
        context,
        ExcludeSemantics(child: PaintedPassphrase(value, style: widget.style)),
        ExcludeSemantics(
          child: AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              painter: _NsecQrPainter(
                value,
                widget.qrForeground,
                widget.qrBackground,
              ),
            ),
          ),
        ),
        () => _copy(generation),
      ),
    };
  }
}

// Keep the matrix private too: its modules encode the same secret as the text.
final class _NsecQrPainter extends CustomPainter {
  final QrImage _image;
  final Color _foreground;
  final Color _background;

  _NsecQrPainter(String nsec, this._foreground, this._background)
    : _image = QrImage(
        QrCode.fromData(data: nsec, errorCorrectLevel: QrErrorCorrectLevel.L),
      );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _background);
    const margin = 4;
    final cell = size.shortestSide / (_image.moduleCount + margin * 2);
    final paint = Paint()
      ..color = _foreground
      ..isAntiAlias = false;
    for (var row = 0; row < _image.moduleCount; row++) {
      for (var col = 0; col < _image.moduleCount; col++) {
        if (_image.isDark(row, col)) {
          canvas.drawRect(
            Rect.fromLTWH(
              (col + margin) * cell,
              (row + margin) * cell,
              cell,
              cell,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_NsecQrPainter oldDelegate) => true;
}
