import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';

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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? context.colour.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(2.0),
          border: Border.all(
            color:
                isSelected
                    ? context.colour.secondaryFixedDim
                    : context.colour.outline,
          ),
        ),
        child: BBText(
          title,
          style: context.font.bodyMedium?.copyWith(
            color:
                isSelected
                    ? context.colour.onSecondary
                    : context.colour.secondary,
          ),
        ),
      ),
    );
  }
}
