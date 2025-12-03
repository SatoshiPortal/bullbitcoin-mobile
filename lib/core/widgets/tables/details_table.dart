import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class DetailsTable extends StatelessWidget {
  const DetailsTable({super.key, required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        border: Border.all(color: context.appColors.outline),
        boxShadow: [
          BoxShadow(
            color: context.appColors.onSurface.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i != items.length - 1)
              Divider(color: context.appColors.outline),
          ],
        ],
      ),
    );
  }
}
