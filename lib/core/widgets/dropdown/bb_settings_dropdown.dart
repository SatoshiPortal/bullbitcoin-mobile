import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class BBSettingsDropdown<T> extends StatelessWidget {
  const BBSettingsDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.labelBuilder,
  });

  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T) labelBuilder;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showDropdownMenu(context),
      borderRadius: BorderRadius.circular(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            labelBuilder(value),
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down,
            color: context.appColors.primary,
            size: 20,
          ),
        ],
      ),
    );
  }

  void _showDropdownMenu(BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showMenu<T>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height,
        offset.dx + size.width,
        0,
      ),
      color: context.appColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: context.appColors.primary.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      items: items.map((item) {
        final isSelected = item == value;
        return PopupMenuItem<T>(
          value: item,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: isSelected
                ? BoxDecoration(
                    color: context.appColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  )
                : null,
            child: Text(
              labelBuilder(item),
              style: context.font.bodyMedium?.copyWith(
                color: isSelected
                    ? context.appColors.primary
                    : context.appColors.text,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    ).then((selectedValue) {
      if (selectedValue != null) {
        onChanged(selectedValue);
      }
    });
  }
}
