import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/settings/bloc/lighting_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class BBSwitcher<T extends Object> extends StatelessWidget {
  const BBSwitcher({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> items;
  final void Function(T) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final item in items.entries)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(item.key),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: value == item.key
                      ? context.colour.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: value == item.key
                        ? context.colour.onPrimary
                        : context.colour.onBackground,
                  ),
                ),
              ),
            ),
          ),
      ],
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
            ? item.label.substring(0, 12) + '...'
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
