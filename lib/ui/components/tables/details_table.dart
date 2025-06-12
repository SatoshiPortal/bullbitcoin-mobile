import 'package:flutter/material.dart';

class DetailsTable extends StatelessWidget {
  const DetailsTable({super.key, required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.onPrimary,
        border: Border.all(color: theme.colorScheme.surface),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow,
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
              Divider(color: theme.colorScheme.secondaryFixedDim),
          ],
        ],
      ),
    );
  }
}
