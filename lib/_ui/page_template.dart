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
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: bottomChild,
          ),
        ),
      ],
    );
  }
}
