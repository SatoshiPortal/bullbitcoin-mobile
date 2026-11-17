import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart' show BullShapesX, BullText;

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
    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kMinInteractiveDimension,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.appColors.onSurface
                    : context.appColors.transparent,
                borderRadius: BorderRadius.circular(context.bullShapes.button),
                border: Border.all(
                  color: isSelected
                      ? context.appColors.onSurface
                      : context.appColors.border,
                ),
              ),
              child: BullText(
                title,
                style: context.font.bodyMedium?.copyWith(
                  color: isSelected
                      ? context.appColors.surface
                      : context.appColors.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
