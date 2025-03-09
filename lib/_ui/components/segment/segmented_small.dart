import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:flutter/cupertino.dart';

class SegmentedSmall extends StatelessWidget {
  const SegmentedSmall({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final Set<String> items;
  final String selected;
  final Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CupertinoSlidingSegmentedControl<String>(
        backgroundColor: context.colour.secondaryFixedDim,
        thumbColor: context.colour.primary,
        groupValue: items.first,
        proportionalWidth: true,
        onValueChanged: (v) => v == null ? null : onSelected(v),
        padding: EdgeInsets.zero,
        children: {
          for (final item in items)
            item: SizedBox(
              height: 48,
              width: 42,
              child: Center(
                child: BBText(
                  item,
                  style: context.font.bodyLarge,
                  color: item == selected
                      ? context.colour.onPrimary
                      : context.colour.secondary,
                ),
              ),
            ),
        },
      ),
    );
  }
}
