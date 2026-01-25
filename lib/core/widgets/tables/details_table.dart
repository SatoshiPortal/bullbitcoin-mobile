import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class DetailsTable extends StatelessWidget {
  const DetailsTable({super.key, required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.appColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.appColors.border.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i != items.length - 1)
              Divider(
                color: context.appColors.border.withValues(alpha: 0.15),
                height: 1,
                thickness: 0.5,
              ),
          ],
        ],
      ),
    );
  }
}
