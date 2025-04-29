import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';

class NumPad extends StatelessWidget {
  final Function(String) onNumberPressed;
  final Function() onBackspacePressed;

  const NumPad({
    super.key,
    required this.onNumberPressed,
    required this.onBackspacePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumberButton(context, '1'),
            _buildNumberButton(context, '2'),
            _buildNumberButton(context, '3'),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumberButton(context, '4'),
            _buildNumberButton(context, '5'),
            _buildNumberButton(context, '6'),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumberButton(context, '7'),
            _buildNumberButton(context, '8'),
            _buildNumberButton(context, '9'),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildEmptyButton(),
            _buildNumberButton(context, '0'),
            _buildBackspaceButton(context),
          ],
        ),
      ],
    );
  }

  Widget _buildNumberButton(BuildContext context, String number) {
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: () => onNumberPressed(number),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: Text(
          number,
          style: context.font.headlineLarge,
        ),
      ),
    );
  }

  Widget _buildEmptyButton() {
    return const SizedBox(
      width: 80,
      height: 80,
    );
  }

  Widget _buildBackspaceButton(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onBackspacePressed,
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.backspace_outlined,
          size: 28,
          color: context.colour.onSurface,
        ),
      ),
    );
  }
}
