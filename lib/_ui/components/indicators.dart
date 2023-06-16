import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class BBSpinner extends StatelessWidget {
  const BBSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class BBLoadingRow extends StatefulWidget {
  const BBLoadingRow({
    super.key,
  });

  @override
  State<BBLoadingRow> createState() => _BBLoadingRowState();
}

class _BBLoadingRowState extends State<BBLoadingRow> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final Cubic firstCurve = Curves.easeInCubic;
  final Cubic seconCurve = Curves.easeOutCubic;
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    const height = 8.0;
    const width = 16.0;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (_, __) => Container(
        height: height,
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: height,
          width: (width * 8) + 8,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (var i = 0; i < 8; i++)
                    DashBox(
                      width: width,
                      isOn: _animationController.value >= i / 8 &&
                          _animationController.value < (i + 1) / 8,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

class DashBox extends StatelessWidget {
  const DashBox({
    super.key,
    required this.width,
    required this.isOn,
  });
  final double width;

  final bool isOn;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: 200.ms,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: isOn ? context.colour.error : context.colour.surface.withOpacity(0.4),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
