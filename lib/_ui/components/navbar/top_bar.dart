import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.title,
    this.onBack,
    this.onAction,
  });

  final String title;
  final Function? onBack;
  final Function? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (onBack != null) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => onBack!(),
              iconSize: 24,
              color: context.colour.secondary,
              visualDensity: VisualDensity.compact,
            ),
          ] else if (onAction != null)
            const Gap(40),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(bottom: 8),
              alignment: Alignment.bottomCenter,
              child: BBText(
                title,
                style: context.font.headlineMedium,
                color: context.colour.secondary,
              ),
            ),
          ),
          if (onAction != null) ...[
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => onAction!(),
              iconSize: 24,
              color: context.colour.secondary,
              visualDensity: VisualDensity.compact,
            ),
          ] else if (onBack != null)
            const Gap(40),
        ],
      ),
    );
  }
}
