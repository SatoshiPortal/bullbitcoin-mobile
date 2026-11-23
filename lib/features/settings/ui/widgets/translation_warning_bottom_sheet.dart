import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullBottomSheet,
        BullButton,
        BullShapesX,
        BullText,
        BullTextRole,
        BullTypographyX;

class TranslationWarningBottomSheet extends StatelessWidget {
  const TranslationWarningBottomSheet({super.key});

  static const String _githubUrl =
      'https://github.com/SatoshiPortal/bullbitcoin-mobile/tree/develop/localization';
  static bool _hasBeenShown = false;

  static Future<void> show(BuildContext context) {
    if (_hasBeenShown) return Future.value();
    _hasBeenShown = true;

    return BullBottomSheet.show(
      context: context,
      child: const TranslationWarningBottomSheet(),
    );
  }

  Future<void> _openGithub() async {
    final url = Uri.parse(_githubUrl);
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
    return SafeArea(
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
                borderRadius: BorderRadius.circular(context.bullShapes.dot),
              ),
            ),
            SizedBox(height: gapL),
            Icon(
              Icons.translate,
              size: iconSize,
              color: context.appColors.primary,
            ),
            SizedBox(height: gapM),
            Semantics(
              header: true,
              child: BullText(
                context.loc.translationWarningTitle,
                role: BullTextRole.subtitle,
                fontWeight: FontWeight.bold,
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: gapS),
            BullText(
              context.loc.translationWarningDescription,
              style: context.bullType.body.copyWith(
                color: context.appColors.secondary.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: gapL),

            BullButton.secondary(
              label: context.loc.translationWarningContributeButton,
              onPressed: () async {
                Navigator.of(context).pop();
                await _openGithub();
              },
            ),
          ],
        ),
      ),
    );
  }
}
