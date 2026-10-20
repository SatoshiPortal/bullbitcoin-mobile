import 'package:bb_mobile/features/buy/ui/widgets/buy_cubes_loader.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
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
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: const BuyCubesLoader(),
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
      ),
    );
  }
}
