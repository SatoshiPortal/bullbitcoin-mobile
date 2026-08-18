import 'package:bull_ui/bull_ui.dart';

class LegacyStorageImportantCallout extends StatelessWidget {
  const LegacyStorageImportantCallout({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.bull.errorContainer,
        border: Border(left: BorderSide(color: context.bull.primary, width: 3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BullIcon(BullIcons.close, color: context.bull.primary, size: 20),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BullText(
                  title,
                  style: context.bullText.bodyMedium?.copyWith(
                    color: context.bull.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(2),
                BullText(
                  body,
                  style: context.bullText.bodyMedium?.copyWith(
                    color: context.bull.onSurface,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
