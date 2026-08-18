import 'package:bull_ui/bull_ui.dart';

class TxsFilterItem extends StatelessWidget {
  const TxsFilterItem({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: BullBorderedTile(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        backgroundColor: isSelected
            ? context.bull.onSurface
            : context.bull.surface,
        child: BullText(
          title,
          style: context.bullText.bodyMedium?.copyWith(
            color: isSelected ? context.bull.surface : context.bull.onSurface,
          ),
        ),
      ),
    );
  }
}
