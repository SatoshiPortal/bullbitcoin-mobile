import 'package:flutter/material.dart';

class TransactionDirectionBadge extends StatelessWidget {
  const TransactionDirectionBadge({super.key, required this.isIncoming});

  final bool isIncoming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.surface),
        color: theme.colorScheme.onPrimary,
        borderRadius: BorderRadius.circular(60),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        isIncoming ? Icons.south_east : Icons.north_east,
        color: theme.colorScheme.secondary,
      ),
    );
  }
}
