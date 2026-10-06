import 'package:bull_ui/bull_ui.dart';
import 'package:shimmer/shimmer.dart';

final class LimitOrdersLoadingBar extends StatelessWidget {
  const LimitOrdersLoadingBar({super.key, this.height = 3});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: context.bull.primary,
      highlightColor: context.bull.onPrimary,
      period: const Duration(milliseconds: 900),
      child: Container(height: height, color: context.bull.primary),
    );
  }
}
