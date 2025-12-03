import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExchangeFileUploadScreen extends StatelessWidget {
  const ExchangeFileUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.secondaryFixed,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.exchangeFileUploadTitle,
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
                  color: context.appColors.onPrimary,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: context.appColors.surface.withValues(alpha: 0.1),
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
                      context.loc.exchangeFileUploadDocumentTitle,
                      style: context.font.bodyLarge?.copyWith(
                        color: context.appColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.loc.exchangeFileUploadInstructions,
                      style: context.font.bodyMedium?.copyWith(
                        color: context.appColors.outline,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: BBButton.big(
                        label: context.loc.exchangeFileUploadButton,
                        onPressed: () {
                          // TODO: Implement file upload functionality
                        },
                        bgColor: context.appColors.secondary,
                        textColor: context.appColors.onPrimary,
                        iconData: Icons.upload,
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
