import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class DisclosureLink extends StatelessWidget {
  const DisclosureLink({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.title,
    required this.body,
  });

  final String label;
  final String semanticLabel;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final color = context.appColors.onSurfaceVariant;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () =>
              DisclosureBottomSheet.show(context, title: title, body: body),
          borderRadius: BorderRadius.circular(2),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 16, color: color),
                const Gap(6),
                Flexible(
                  child: BBText(
                    label,
                    style: context.font.labelSmall,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DisclosureBottomSheet extends StatelessWidget {
  const DisclosureBottomSheet({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    return BlurredBottomSheet.show(
      context: context,
      child: DisclosureBottomSheet(title: title, body: body),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: BBText(title, style: context.font.headlineMedium),
                ),
                IconButton(
                  tooltip: context.loc.closeDialogButton,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: BBText(
                body,
                style: context.font.bodyMedium,
                color: context.appColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
