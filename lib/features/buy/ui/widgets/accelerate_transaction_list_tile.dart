import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
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
        color: context.appColors.onPrimary, // or Colors.white
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: context.appColors.secondary),
        boxShadow: [
          BoxShadow(
            color: context.appColors.surface,
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
                valueColor: AlwaysStoppedAnimation<Color>(
                  context.appColors.warning,
                ),
                backgroundColor: context.appColors.shimmerBase,
              ),
            ),
            Icon(Icons.schedule, size: 16, color: context.appColors.secondary),
          ],
        ),
        title: Text(
          context.loc.buyAccelerateTransaction,
          style: theme.textTheme.headlineLarge?.copyWith(
            color: context.appColors.secondary,
          ),
        ),
        subtitle: Text(
          context.loc.buyGetConfirmedFaster,
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.appColors.secondary,
          ),
        ),
        trailing: Icon(
          Icons.fast_forward_outlined,
          color: context.appColors.secondary,
        ),
        onTap: onTap,
      ),
    );
  }
}
