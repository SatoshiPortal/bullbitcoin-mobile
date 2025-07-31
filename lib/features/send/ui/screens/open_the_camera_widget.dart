import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/send/ui/screens/full_screen_scanner_page.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class OpenTheCameraWidget extends StatelessWidget {
  final OnScannedPaymentRequestCallback onScannedPaymentRequest;

  const OpenTheCameraWidget({super.key, required this.onScannedPaymentRequest});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colour.secondaryFixedDim,
      child: Column(
        children: [
          const Gap(30),
          Image.asset(Assets.misc.qRPlaceholder.path, height: 110, width: 110),
          const Gap(24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: BBText(
              'Scan any Bitcoin or Lightning QR code to pay with bitcoin.',
              style: context.font.bodyMedium,
              color: context.colour.outlineVariant,
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ),
          const Gap(24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 52),
            child: BBButton.small(
              outlined: true,
              onPressed: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder:
                        (context, _, _) => FullScreenScannerPage(
                          onScannedPaymentRequest: onScannedPaymentRequest,
                        ),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) =>
                            child,
                  ),
                );
              },
              label: 'Open the Camera',
              bgColor: Colors.transparent,
              borderColor: context.colour.surfaceContainer,
              textColor: context.colour.secondary,
            ),
          ),
          const Gap(24),
        ],
      ),
    );
  }
}
