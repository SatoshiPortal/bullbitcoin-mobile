import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart';

class PrivacyNoticeBottomSheet extends StatelessWidget {
  const PrivacyNoticeBottomSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return BullBottomSheet.show<bool?>(
      context: context,
      child: const PrivacyNoticeBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: context.appColors.onPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Column(
              children: [
                const Gap(20),
                Row(
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    const Gap(24),
                    Text(
                      context.loc.electrumPrivacyNoticeTitle,
                      style: context.font.headlineMedium,
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(false),
                      child: const Icon(Icons.close),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Text(
                      context.loc.electrumPrivacyNoticeContent1,
                      style: context.font.bodyMedium,
                      maxLines: 4,
                    ),
                    const Gap(24),
                    Text(
                      context.loc.electrumPrivacyNoticeContent2,
                      maxLines: 4,
                      style: context.font.bodyMedium,
                    ),
                    const Gap(32),
                    Row(
                      children: [
                        Expanded(
                          child: BullButton.secondary(
                            label: context.loc.electrumPrivacyNoticeCancel,
                            onPressed: () => Navigator.of(context).pop(false),
                          ),
                        ),
                        const Gap(16),
                        Expanded(
                          child: BullButton.primary(
                            label: context.loc.electrumPrivacyNoticeSave,
                            onPressed: () => Navigator.of(context).pop(true),
                          ),
                        ),
                      ],
                    ),
                    const Gap(30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
