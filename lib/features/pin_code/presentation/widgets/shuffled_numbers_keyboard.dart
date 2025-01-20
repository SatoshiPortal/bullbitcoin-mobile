import 'package:flutter/material.dart';

class ShuffledNumbersKeyboard extends StatelessWidget {
  final List<dynamic> items; // Use dynamic to handle both numbers and backspace
  final void Function(int) onNumberSelected;
  final void Function() onBackspacePressed;
  final bool? disableBackspace;
  final bool? disableKeys;

  ShuffledNumbersKeyboard({
    required this.onNumberSelected,
    required this.onBackspacePressed,
    this.disableBackspace,
    this.disableKeys,
  }) : items = List<int>.generate(10, (i) => i)..shuffle() {
    items.add('backspace'); // Add backspace as the last element
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        if (item == 'backspace') {
          return BackspaceButton(
            onPressed: onBackspacePressed,
            disabled: disableBackspace,
          );
        } else {
          return NumberButton(
            number: item as int,
            onPressed: () => onNumberSelected(item),
            disabled: disableKeys,
          );
        }
      },
    );
  }
}

class NumberButton extends StatelessWidget {
  final int number;
  final Function() onPressed;
  final bool? disabled;

  const NumberButton({
    required this.number,
    required this.onPressed,
    this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      // Number button should be enabled at start
      onPressed: (disabled ?? false) ? null : onPressed,
      child: Text(number.toString()),
    );
  }
}

class BackspaceButton extends StatelessWidget {
  final Function() onPressed;
  final bool? disabled;

  const BackspaceButton({
    required this.onPressed,
    this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      // Backspace button should be disabled at start
      onPressed: (disabled ?? true) ? null : onPressed,
      child: const Icon(Icons.backspace),
    );
  }
}
