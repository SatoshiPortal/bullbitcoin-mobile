import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart' show Assets;
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:gif/gif.dart' show Autostart, Gif;

class ProgressScreen extends StatelessWidget {
  final String? title;
  final String? description;
  final bool isLoading;
  final List<Widget> extras;
  const ProgressScreen({
    required this.isLoading,
    super.key,
    this.title,
    this.description,
    this.extras = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            Center(
              child: Gif(
                autostart: Autostart.loop,
                width: 200,
                height: 200,
                image: AssetImage(Assets.animations.cubesLoading.path),
              ),
            )
          else
            const SizedBox.shrink(),
          if (title != null) ...[
            const Gap(16),
            BBText(
              title!,
              textAlign: TextAlign.center,
              style: context.font.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (description != null) ...[
            const Gap(16),
            BBText(
              description!,
              textAlign: TextAlign.center,
              style: context.font.bodySmall,
              maxLines: 3,
            ),
          ],
          if (extras.isNotEmpty) ...[const Gap(16), ...extras],
        ],
      ),
    );
  }
}
