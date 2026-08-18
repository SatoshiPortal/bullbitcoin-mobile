import 'package:bull_ui/bull_ui.dart';

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
    return BullBorderedTile(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BullText(title, style: context.bullText.bodyLarge),
                BullText(subtitle, style: context.bullText.labelMedium),
              ],
            ),
          ),
          const BullIcon(BullIcons.chevronRight),
        ],
      ),
    );
  }
}
