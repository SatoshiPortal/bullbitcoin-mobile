import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/settings/bloc/lighting_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

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

  Widget _buildItem(String title, {bool darkMode = false}) {
    return SizedBox(
      height: 40,
      width: 120,
      child: Center(
        child: BBText.bodySmall(
          title,
          isBold: true,
          onSurface: darkMode,
          fontSize: 14,
        ),
      ),
    );
  }

  Map<T, Widget> _buildItems(bool darkMode) {
    final map = <T, Widget>{};
    for (final key in items.keys) {
      map[key] = _buildItem(items[key]!, darkMode: darkMode);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = context.select(
      (Lighting x) => x.state.currentTheme(context) == ThemeMode.dark,
    );

    final colour =
        darkMode ? context.colour.primaryContainer : context.colour.surface;

    final borderColour =
        darkMode ? context.colour.onPrimaryContainer : context.colour.onSurface;

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(
          Radius.circular(8.0),
        ),
        border: Border.all(color: borderColour),
      ),
      child: CupertinoSlidingSegmentedControl(
        groupValue: value,
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        children: _buildItems(darkMode),
        backgroundColor: colour,
        onValueChanged: (v) {
          if (v == null) return;
          onChanged.call(v);
        },
      ),
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
    this.walletSelector =
        false, // TODO: Ideally build a WalletSelector control that wraps BBDropDown
  });

  final Map<T, ({String label, bool enabled, String? imagePath})> items;
  final void Function(T) onChanged;
  final T value;
  final bool isCentered;
  final bool walletSelector;

  @override
  Widget build(BuildContext context) {
    final darkMode = context.select(
      (Lighting x) => x.state.currentTheme(context) == ThemeMode.dark,
    );

    final bgColour =
        darkMode ? context.colour.onPrimaryContainer : NewColours.offWhite;

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
          dropdownColor: context.colour.primaryContainer,
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
            fillColor: context.colour.primaryContainer,
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
          // selectedItemBuilder: walletSelector == true && value != null
          //     ? (context) => [value].map((key) {
          //           final widget = buildMenuItem(key, shorten: true);
          //           return widget;
          //         }).toList()
          //     : null,
          items: [
            for (final key in items.keys)
              DropdownMenuItem<T>(
                value: key,
                enabled: items[key]!.enabled,
                child: buildMenuItem(key),
              ),
          ],
        ),
      ),
    );

    // return widget;
    if (isCentered) {
      return Center(
        child: widget,
      );
    } else {
      return widget;
    }
  }

  Opacity buildMenuItem<U>(U key, {bool shorten = false}) {
    final ({String label, bool enabled, String? imagePath}) item = items[key]!;

    final text = shorten
        ? item.label.length > 12
            ? '${item.label.substring(0, 12)}...'
            : item.label
        : item.label;

    final textWidget = BBText.body(text);

    if (item.imagePath == null) {
      return Opacity(
        key: Key(item.label),
        opacity: item.enabled ? 1 : 0.3,
        child: isCentered
            ? Center(
                child: textWidget,
              )
            : textWidget,
      );
    }

    final textWithLogo = Row(
      children: [
        textWidget,
        const Gap(4),
        Image.asset(
          item.imagePath ?? '',
          width: 24,
          height: 24,
        ),
      ],
    );

    return Opacity(
      key: Key(item.label),
      opacity: item.enabled ? 1 : 0.3,
      // child: textWithLogo,
      child: isCentered
          ? Center(
              child: textWithLogo,
            )
          : textWithLogo,
    );
  }
}

class BBSwitch extends StatelessWidget {
  const BBSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(
      activeColor: context.colour.primaryContainer,
      activeTrackColor: context.colour.onPrimaryContainer,
      inactiveTrackColor: context.colour.surface,
      inactiveThumbColor: context.colour.onPrimaryContainer.withOpacity(0.4),
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
