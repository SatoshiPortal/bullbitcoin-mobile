import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
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
      color: context.appColors.secondaryFixedDim,
      child: Column(
        children: [
          const Gap(30),
          Image.asset(Assets.misc.qRPlaceholder.path, height: 110, width: 110),
          const Gap(24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              context.loc.sendScanBitcoinQRCode,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.outlineVariant,
              ),
              textAlign: .center,
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
                    pageBuilder: (context, _, _) => FullScreenScannerPage(
                      onScannedPaymentRequest: onScannedPaymentRequest,
                    ),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) =>
                            child,
                  ),
                );
              },
              label: context.loc.sendOpenTheCamera,
              bgColor: context.appColors.transparent,
              borderColor: context.appColors.surfaceContainer,
              textColor: context.appColors.secondary,
            ),
          ),
          const Gap(24),
        ],
      ),
    );
  }
}
