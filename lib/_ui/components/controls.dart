import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BBSwitcher<T> extends StatelessWidget {
  const BBSwitcher({
    super.key,
    required this.items,
    required this.onChanged,
    required this.value,
  });

  final Map<T, String> items;
  final void Function(T) onChanged;
  final T value;

  Widget _buildItem(String title) {
    return SizedBox(
      height: 40,
      child: Center(
        child: BBText.body(title, isBold: true),
      ),
    );
  }

  Map<T, Widget> _buildItems() {
    final map = <T, Widget>{};
    for (final key in items.keys) {
      map[key] = _buildItem(items[key]!);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoSlidingSegmentedControl(
      groupValue: value,
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      children: _buildItems(),
      onValueChanged: (v) {
        if (v == null) return;
        onChanged.call(v);
      },
    );
  }
}

class BBDropDown<T> extends StatelessWidget {
  const BBDropDown({
    super.key,
    required this.items,
    required this.onChanged,
    required this.value,
  });

  final Map<T, String> items;
  final void Function(T) onChanged;
  final T value;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 250,
        height: 45,
        child: Material(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(8),
          child: DropdownButtonFormField<T>(
            padding: EdgeInsets.zero,
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            isExpanded: true,
            decoration: InputDecoration(
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(
                  color: NewColours.lightGray,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              border: OutlineInputBorder(
                borderSide: const BorderSide(
                  color: NewColours.lightGray,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: NewColours.offWhite,
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(
                  color: NewColours.lightGray,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            value: value,
            onChanged: (value) {
              if (value == null) return;
              onChanged.call(value);
            },
            items: [
              for (final key in items.keys)
                DropdownMenuItem<T>(
                  value: key,
                  child: Center(
                    child: BBText.body(items[key]!),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
