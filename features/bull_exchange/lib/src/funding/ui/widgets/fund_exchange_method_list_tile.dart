import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';

class FundExchangeMethodListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final void Function()? onTap;

  const FundExchangeMethodListTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: context.appColors.transparent,
      shape: const RoundedRectangleBorder(),
      title: BullText(
        title,
        style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: BullText(
        subtitle,
        style: context.bullType.caption,
        color: context.appColors.outline,
      ),
      onTap: onTap,
      trailing: const Icon(Icons.arrow_forward),
    );
  }
}
