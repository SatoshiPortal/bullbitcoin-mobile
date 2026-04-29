import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TranslationWarningBottomSheet extends StatelessWidget {
  const TranslationWarningBottomSheet({super.key});

  static const String _contributeUrl =
      'https://github.com/SatoshiPortal/bullbitcoin-mobile';
  static bool _hasBeenShown = false;

  static Future<void> show(BuildContext context) {
    if (_hasBeenShown) return Future.value();
    _hasBeenShown = true;

    return BlurredBottomSheet.show(
      context: context,
      child: const TranslationWarningBottomSheet(),
    );
  }

  Future<void> _openContributeLink() async {
    final url = Uri.parse(_contributeUrl);
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final pad = Device.screen.width * 0.06;
    final gapL = Device.screen.height * 0.03;
    final gapM = Device.screen.height * 0.02;
    final gapS = Device.screen.height * 0.01;
    final grabWidth = Device.screen.width * 0.10;
    final iconSize = Device.screen.height * 0.06;
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: grabWidth,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appColors.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: gapL),
              Icon(
                Icons.translate,
                size: iconSize,
                color: context.appColors.primary,
              ),
              SizedBox(height: gapM),
              BBText(
                context.loc.translationWarningTitle,
                style: context.font.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: gapS),
              BBText(
                context.loc.translationWarningDescription,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.secondary.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: gapL),

              BBButton.big(
                label: context.loc.translationWarningContributeButton,
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _openContributeLink();
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
