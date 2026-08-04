import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gif/gif.dart';

class NfcScanView extends StatelessWidget {
  const NfcScanView({
    super.key,
    required this.isScanning,
    this.errorMessage,
    this.onRetry,
  });

  final bool isScanning;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final errorMessage = this.errorMessage;
    final onRetry = this.onRetry;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isScanning) ...[
          SizedBox(
            width: 250,
            height: 250,
            child: Gif(
              image: AssetImage(Assets.animations.nfcPoll.path),
              autostart: Autostart.loop,
            ),
          ),
          BBText(
            context.loc.nfcScanInstructions,
            style: context.font.bodyMedium,
            color: context.appColors.textMuted,
            textAlign: TextAlign.center,
          ),
        ] else ...[
          Icon(
            Icons.nfc,
            size: 64,
            color: errorMessage == null
                ? context.appColors.textMuted
                : context.appColors.error,
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            BBText(
              errorMessage,
              style: context.font.bodyMedium,
              color: context.appColors.text,
              textAlign: TextAlign.center,
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            BBButton.big(
              label: context.loc.statusScreenTryAgain,
              onPressed: onRetry,
              bgColor: context.appColors.onPrimary,
              textColor: context.appColors.secondary,
              iconData: Icons.nfc,
            ),
          ],
        ],
      ],
    );
  }
}
