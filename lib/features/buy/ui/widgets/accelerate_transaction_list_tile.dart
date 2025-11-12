import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

class AccelerateTransactionListTile extends StatelessWidget {
  const AccelerateTransactionListTile({
    super.key,
    required this.orderId,
    required this.onTap,
  });

  final String orderId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.onPrimary, // or Colors.white
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.colorScheme.secondary),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.surface,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                value: 0.75, // portion of the circle to fill
                strokeWidth: 4,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                backgroundColor: Colors.grey.shade300,
              ),
            ),
            Icon(Icons.schedule, size: 16, color: theme.colorScheme.secondary),
          ],
        ),
        title: Text(
          context.loc.buyAccelerateTransaction,
          style: theme.textTheme.headlineLarge?.copyWith(
            color: theme.colorScheme.secondary,
          ),
        ),
        subtitle: Text(
          context.loc.buyGetConfirmedFaster,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.secondary,
          ),
        ),
        trailing: Icon(
          Icons.fast_forward_outlined,
          color: theme.colorScheme.secondary,
        ),
        onTap: onTap,
      ),
    );
  }
}
