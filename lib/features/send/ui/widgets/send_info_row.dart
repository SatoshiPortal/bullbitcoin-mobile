import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

class SendInfoRow extends StatelessWidget {
  final String title;
  final Widget details;

  const SendInfoRow({super.key, required this.title, required this.details});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          BBText(
            title,
            style: context.font.bodySmall,
            color: context.appColors.onSurfaceVariant,
          ),
          const Gap(24),
          Expanded(child: details),
        ],
      ),
    );
  }
}
