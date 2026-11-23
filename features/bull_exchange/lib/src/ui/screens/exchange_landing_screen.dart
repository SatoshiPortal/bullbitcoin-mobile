import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullThemeX,
        BullText,
        BullButton,
        BullShapesX,
        BullTypography,
        Gap,
        BullTypographyX;

import '../../exchange_landing_copy.dart';

class ExchangeLandingScreen extends StatelessWidget {
  final ExchangeLandingCopy copy;
  final String brandAssetPath;
  final VoidCallback onSignIn;
  final VoidCallback onExit;

  const ExchangeLandingScreen({
    required this.copy,
    required this.brandAssetPath,
    required this.onSignIn,
    required this.onExit,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return; // Don't allow back navigation

        // Navigate to the wallet home screen when the user wants to exit the
        // exchange landing screen.
        onExit();
      },
      child: Scaffold(
        backgroundColor: context.bull.background,
        appBar: AppBar(
          leading: BackButton(color: context.bull.onSurface, onPressed: onExit),
        ),
        extendBodyBehindAppBar: true,
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Gap(32),
                    Center(
                      child: Column(
                        children: [
                          Image.asset(brandAssetPath, width: 120, height: 120),
                          const Gap(16),
                          BullText(
                            copy.brandName,
                            style: TextStyle(
                              fontFamily: BullTypography.brandFamily,
                              color: context.bull.primary,
                              fontSize: 64, // Brand wordmark: a layout size, not a role (bull-ui-check allowlist).
                            ),
                          ),
                          const Gap(12),
                          BullText(
                            copy.connectAccount,
                            style: context.bullType.subtitle
                                .copyWith(fontWeight: FontWeight.w400)
                                .copyWith(color: context.bull.onSurface),
                          ),
                        ],
                      ),
                    ),
                    const Gap(32),
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: context.bull.surfaceContainer,
                        border: Border.all(
                          color: context.bull.outline,
                          width: 0,
                        ),
                        borderRadius: BorderRadius.circular(
                          context.bullShapes.card,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BullText(
                            copy.selfCustody,
                            style: context.bullType.body
                                .copyWith(fontWeight: FontWeight.w500)
                                .copyWith(color: context.bull.onSurface),
                          ),
                          const Gap(12),
                          BullText(
                            copy.recurringOrders,
                            style: context.bullType.body
                                .copyWith(fontWeight: FontWeight.w500)
                                .copyWith(color: context.bull.onSurface),
                          ),
                          const Gap(12),
                          BullText(
                            copy.sellBitcoin,
                            style: context.bullType.body
                                .copyWith(fontWeight: FontWeight.w500)
                                .copyWith(color: context.bull.onSurface),
                          ),
                          const Gap(12),
                          BullText(
                            copy.bankTransfers,
                            style: context.bullType.body
                                .copyWith(fontWeight: FontWeight.w500)
                                .copyWith(color: context.bull.onSurface),
                          ),
                          const Gap(12),
                          BullText(
                            copy.customerSupport,
                            style: context.bullType.body
                                .copyWith(fontWeight: FontWeight.w500)
                                .copyWith(color: context.bull.onSurface),
                          ),
                          const Gap(12),
                          BullText(
                            copy.unifiedHistory,
                            style: context.bullType.body
                                .copyWith(fontWeight: FontWeight.w500)
                                .copyWith(color: context.bull.onSurface),
                          ),
                        ],
                      ),
                    ),
                    const Gap(16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.bull.warningContainer,
                        borderRadius: BorderRadius.circular(
                          context.bullShapes.card,
                        ),
                      ),
                      child: BullText(
                        copy.legalDisclaimer,
                        style: context.bullType.label
                            .copyWith(fontWeight: FontWeight.w400)
                            .copyWith(color: context.bull.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13.0),
              child: SizedBox(
                width: double.infinity,
                child: BullButton.primary(
                  label: copy.signIn,
                  onPressed: onSignIn,
                ),
              ),
            ),
            const Gap(16),
          ],
        ),
      ),
    );
  }
}
