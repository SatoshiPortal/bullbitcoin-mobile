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
import 'package:url_launcher/url_launcher.dart';

import '../../exchange_landing_copy.dart';

class ExchangeLandingScreenV2 extends StatelessWidget {
  final ExchangeLandingCopy copy;
  final String brandAssetPath;
  final VoidCallback onExit;

  const ExchangeLandingScreenV2({
    required this.copy,
    required this.brandAssetPath,
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
        backgroundColor: context.bull.surface,
        appBar: AppBar(
          leading: BackButton(color: context.bull.onSurface, onPressed: onExit),
        ),
        extendBodyBehindAppBar: true,
        body: SingleChildScrollView(
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
                      copy.recommendedExchange,
                      style: context.bullType.subtitle
                          .copyWith(fontWeight: FontWeight.w400)
                          .copyWith(color: context.bull.onSurface),
                    ),
                  ],
                ),
              ),
              const Gap(32),
              // Features List Box
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(color: context.bull.primary, width: 0),
                  borderRadius: BorderRadius.circular(context.bullShapes.card),
                ),
                child: Column(
                  crossAxisAlignment: .start,
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
              // Disclaimer Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.bull.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(context.bullShapes.card),
                ),
                child: Row(
                  crossAxisAlignment: .start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: context.bull.onSurface,
                      size: 20,
                    ),
                    const Gap(8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: .start,
                        children: [
                          BullText(
                            copy.unavailableDisclaimer,
                            style: context.bullType.label
                                .copyWith(fontWeight: FontWeight.w400)
                                .copyWith(color: context.bull.onSurface),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(40),
              // Call-to-Action Button
              SizedBox(
                width: double.infinity,
                child: BullButton.primary(
                  label: copy.openWebsite,
                  onPressed: () async {
                    final Uri url = Uri.parse('https://app.bullbitcoin.com');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
              ),
              const Gap(32),
            ],
          ),
        ),
      ),
    );
  }
}
