import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

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
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.onPrimary, // or Colors.white
        borderRadius: BorderRadius.circular(context.bullShapes.card),
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
          leading: const BullLoader.small(),
          title: Text(
            context.loc.buyAccelerateTransaction,
            style: context.bullType.subtitle
                .copyWith(fontWeight: FontWeight.w700)
                .copyWith(color: context.appColors.secondary),
          ),
          subtitle: Text(
            context.loc.buyGetConfirmedFaster,
            style: context.bullType.label
                .copyWith(fontWeight: FontWeight.w400)
                .copyWith(color: context.appColors.secondary),
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
