import 'package:flutter/material.dart';
import '../theme/bull_theme.dart';
import '../theme/bull_tokens.dart';
import '../assets/bull_assets.dart';
import '../data_display/bull_text.dart';
import 'package:gif/gif.dart';

/// Shared themed progress layout with the design system's loading animation.
class BullProgressScreen extends StatelessWidget {
  final bool isLoading;
  final String? title;
  final String? description;

  const BullProgressScreen({
    super.key,
    required this.isLoading,
    this.title,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BullSpacing.xs),
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
            BullText(
              title!,
              style: context.bullText.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (description != null) ...[
            const SizedBox(height: BullSpacing.md),
            BullText(
              description!,
              style: context.bullText.bodySmall,
              maxLines: 3,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
