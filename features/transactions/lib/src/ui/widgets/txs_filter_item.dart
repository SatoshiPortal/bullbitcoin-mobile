import 'package:bull_ui/bull_ui.dart' show BullThemeX;
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullShapesX, BullText, BullTypographyX;

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
                    ? context.bull.onSurface
                    : context.bull.transparent,
                borderRadius: BorderRadius.circular(context.bullShapes.button),
                border: Border.all(
                  color: isSelected
                      ? context.bull.onSurface
                      : context.bull.border,
                ),
              ),
              child: BullText(
                title,
                style: context.bullType.body.copyWith(
                  color: isSelected
                      ? context.bull.surface
                      : context.bull.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
