import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class ExchangeReferralsScreen extends StatelessWidget {
  const ExchangeReferralsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.exchangeReferralsTitle,
          onBack: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.appColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.loc.exchangeReferralsJoinMissionTitle,
                      style: context.font.bodyLarge?.copyWith(
                        color: context.appColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.loc.exchangeReferralsContactSupportMessage,
                      style: context.font.bodyMedium?.copyWith(
                        color: context.appColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.loc.exchangeReferralsApplyToJoinMessage,
                      style: context.font.bodyMedium?.copyWith(
                        color: context.appColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final url = Uri.parse(
                          'https://bullbitcoin.com/mission',
                        );
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      },
                      child: Text(
                        context.loc.exchangeReferralsMissionLink,
                        style: context.font.bodyLarge?.copyWith(
                          color: context.appColors.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
