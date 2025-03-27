import 'package:flutter/material.dart';

class NumericKeyboard extends StatelessWidget {
  final List<int> numbers;
  final void Function(int) onNumberPressed;
  final void Function() onBackspacePressed;

  const NumericKeyboard({
    super.key,
    required this.numbers,
    required this.onNumberPressed,
    required this.onBackspacePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: numbers.length + 1, // Add one for backspace
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
        ),
        itemBuilder: (context, index) {
          if (index == numbers.length) {
            final number = numbers[index - 1];
            return NumberButton(
              number: number,
              onPressed: () => onNumberPressed(number),
            );
          } else if (index == numbers.length - 1) {
            return BackspaceButton(
              onPressed: onBackspacePressed,
            );
          } else {
            final number = numbers[index];
            return NumberButton(
              number: number,
              onPressed: () => onNumberPressed(number),
            );
          }
        },
      ),
    );
  }
}

class NumberButton extends StatelessWidget {
  final int number;
  final Function()? onPressed;

  const NumberButton({
    super.key,
    required this.number,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      // Number button should be enabled at start
      onPressed: onPressed,
      child: Text(number.toString()),
    );
  }
}

class BackspaceButton extends StatelessWidget {
  final Function()? onPressed;

  const BackspaceButton({
    super.key,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      // Backspace button should be disabled at start
      onPressed: onPressed,
      child: const Icon(Icons.backspace),
    );
  }
}
