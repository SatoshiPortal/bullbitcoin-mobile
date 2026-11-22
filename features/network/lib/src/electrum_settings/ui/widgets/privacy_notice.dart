import '../../../network_l10n.dart';

import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullBottomSheet, BullButton, Gap, BullTypographyX;

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
                      style: context.bullType.subtitle.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    IconButton(
                      tooltip: context.loc.electrumCloseTooltip,
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
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
                      style: context.bullType.body,
                      maxLines: 4,
                    ),
                    const Gap(24),
                    Text(
                      context.loc.electrumPrivacyNoticeContent2,
                      maxLines: 4,
                      style: context.bullType.body,
                    ),
                    const Gap(32),
                    Row(
                      children: [
                        Expanded(
                          child: BullButton.secondary(
                            label: context.loc.electrumPrivacyNoticeCancel,
                            onPressed: () => Navigator.of(context).pop(false),
                            textStyle: context.bullType.subtitle.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Gap(16),
                        Expanded(
                          child: BullButton.primary(
                            label: context.loc.electrumPrivacyNoticeSave,
                            onPressed: () => Navigator.of(context).pop(true),
                            textStyle: context.bullType.subtitle.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
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
