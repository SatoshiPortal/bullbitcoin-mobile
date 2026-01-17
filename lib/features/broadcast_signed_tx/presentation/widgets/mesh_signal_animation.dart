import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class MeshSignalAnimation extends StatefulWidget {
  const MeshSignalAnimation({super.key});

  @override
  State<MeshSignalAnimation> createState() => _MeshSignalAnimationState();
}

class _MeshSignalAnimationState extends State<MeshSignalAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: 200,
      child: CustomPaint(
        painter: _RipplePainter(
          _controller,
          color: context.appColors.primary,
        ),
        child: Center(
          child: Icon(
            Icons.bluetooth_audio,
            size: 48,
            color: context.appColors.primary,
          ),
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final Animation<double> _animation;
  final Color color;

  _RipplePainter(this._animation, {required this.color})
      : super(repaint: _animation);

  void circle(Canvas canvas, Rect rect, double value) {
    final double opacity = (1.0 - (value / 4.0)).clamp(0.0, 1.0);
    final Color currentColor = color.withOpacity(opacity);
    final double size = rect.width / 2;
    final double radius = size * value; // Grows larger

    final Paint paint = Paint()
      ..color = currentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2; // Thin sleek lines

    canvas.drawCircle(rect.center, radius, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTRB(0.0, 0.0, size.width, size.height);
    
    // Draw 3 ripples at different offsets
    for (int wave = 0; wave <= 2; wave++) {
      circle(canvas, rect, (_animation.value + wave) / 3.0);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) => true;
}
