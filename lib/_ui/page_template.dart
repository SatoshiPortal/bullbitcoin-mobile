import 'package:bb_mobile/styles.dart';
import 'package:extra_alignments/extra_alignments.dart';
import 'package:flutter/widgets.dart';

class StackedPage extends StatelessWidget {
  const StackedPage({
    super.key,
    required this.child,
    required this.bottomChild,
  });

  final Widget child;
  final Widget bottomChild;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        BottomCenter(
          child: Container(
            color: context.colour.surface.withOpacity(0.1),
            padding: const EdgeInsets.only(bottom: 16, top: 8, left: 16, right: 16),
            child: bottomChild,
          ),
        ),
      ],
    );
  }
}
