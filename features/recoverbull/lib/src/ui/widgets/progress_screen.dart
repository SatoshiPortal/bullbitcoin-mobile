import 'package:bull_ui/bull_ui.dart';
import 'package:gif/gif.dart';
import 'bull_aliases.dart';
import 'with_bull_theme.dart';

/// The root progress layout, retained locally because it combines the package
/// progress primitive with RecoverBull's loading animation and copy.
class ProgressScreen extends StatelessWidget {
  final bool isLoading;
  final String? title;
  final String? description;

  const ProgressScreen({
    super.key,
    required this.isLoading,
    this.title,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading) ...[
            Gif(
              autostart: Autostart.loop,
              width: 200,
              height: 200,
              image: BullAssets.animations.cubesLoading,
            ),
          ],
          if (title != null) ...[
            const SizedBox(height: BullSpacing.md),
            BBText(
              title!,
              style: context.font.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (description != null) ...[
            const SizedBox(height: BullSpacing.md),
            BBText(
              description!,
              style: context.font.bodySmall,
              maxLines: 3,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
