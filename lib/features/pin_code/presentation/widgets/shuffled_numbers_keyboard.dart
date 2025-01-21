import 'package:flutter/material.dart';

class ShuffledNumbersKeyboard extends StatefulWidget {
  final void Function(int)? onNumberSelected;
  final void Function()? onBackspacePressed;

  const ShuffledNumbersKeyboard({
    super.key,
    this.onNumberSelected,
    this.onBackspacePressed,
  });

  @override
  State<StatefulWidget> createState() => ShuffledNumbersKeyboardState();
}

class ShuffledNumbersKeyboardState extends State<ShuffledNumbersKeyboard> {
  late List<int> shuffledNumbers;

  @override
  void initState() {
    super.initState();
    shuffledNumbers = List<int>.generate(10, (i) => i)..shuffle();
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: shuffledNumbers.length + 1, // Add one for backspace
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        if (index == shuffledNumbers.length) {
          final number = shuffledNumbers[index - 1];
          return NumberButton(
            number: number,
            onPressed: widget.onNumberSelected == null
                ? null
                : () => widget.onNumberSelected!(number),
          );
        } else if (index == shuffledNumbers.length - 1) {
          return BackspaceButton(
            onPressed: widget.onBackspacePressed,
          );
        } else {
          final number = shuffledNumbers[index];
          return NumberButton(
            number: number,
            onPressed: widget.onNumberSelected == null
                ? null
                : () => widget.onNumberSelected!(number),
          );
        }
      },
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
