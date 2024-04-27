import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/settings/bloc/lighting_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
      width: 120,
      child: Center(
        child: BBText.bodySmall(
          title,
          isBold: true,
          fontSize: 14,
        ),
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
      backgroundColor: context.colour.surface,
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
    this.isCentered = true,
  });

  final Map<T, String> items;
  final void Function(T) onChanged;
  final T value;
  final bool isCentered;

  @override
  Widget build(BuildContext context) {
    final darkMode = context.select((Lighting x) => x.state.currentTheme(context) == ThemeMode.dark);

    final bgColour = darkMode ? context.colour.background : NewColours.offWhite;

    final widget = SizedBox(
      width: 225,
      height: 45,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(
            Radius.circular(8.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: DropdownButtonFormField<T>(
          padding: EdgeInsets.zero,
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          isExpanded: true,
          decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: bgColour,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            border: OutlineInputBorder(
              borderSide: BorderSide(
                color: bgColour,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: bgColour,
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: bgColour),
              borderRadius: BorderRadius.circular(8),
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
                child: isCentered
                    ? Center(
                        child: BBText.body(items[key]!),
                      )
                    : BBText.body(items[key]!),
              ),
          ],
        ),
      ),
    );

    if (isCentered) {
      return Center(
        child: widget,
      );
    } else {
      return widget;
    }
  }
}

class BBSwitch extends StatelessWidget {
  const BBSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(
      activeColor: context.colour.background,
      activeTrackColor: context.colour.onBackground,
      inactiveTrackColor: context.colour.surface,
      inactiveThumbColor: context.colour.onBackground.withOpacity(0.4),
      value: value,
      onChanged: onChanged,
    );
  }
}

class ScrollCubit extends Cubit<ScrollController> {
  ScrollCubit() : super(ScrollController());

  @override
  Future<void> close() {
    state.dispose();
    return super.close();
  }
}
