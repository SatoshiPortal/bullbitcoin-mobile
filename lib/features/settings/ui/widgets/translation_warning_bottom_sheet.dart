import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TranslationWarningBottomSheet extends StatelessWidget {
  const TranslationWarningBottomSheet({super.key});

  static const String _weblateUrl = 'https://hosted.weblate.org/engage/bull/';
  static bool _hasBeenShown = false;

  static Future<void> show(BuildContext context) {
    if (_hasBeenShown) return Future.value();
    _hasBeenShown = true;

    return BlurredBottomSheet.show(
      context: context,
      child: const TranslationWarningBottomSheet(),
    );
  }

  Future<void> _openWeblate() async {
    final url = Uri.parse(_weblateUrl);
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appColors.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Icon(Icons.translate, size: 48, color: context.appColors.primary),
              const SizedBox(height: 16),
              BBText(
                context.loc.translationWarningTitle,
                style: context.font.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              BBText(
                context.loc.translationWarningDescription,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.secondary.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),

              BBButton.big(
                label: context.loc.translationWarningContributeButton,
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _openWeblate();
                },
                bgColor: context.appColors.secondary,
                textColor: context.appColors.onSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
