import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:bb_mobile/_ui/themes/values/corners.dart';
import 'package:flutter/material.dart';

enum _ButtonPosition { first, last, middle }

class ActionCard extends StatelessWidget {
  const ActionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(0.5),
          child: Container(
            color: context.colour.secondaryFixed,
          ),
        ),
        Row(
          spacing: 1,
          children: [
            _ActionButton(
              icon: 'buy',
              label: 'Buy',
              onPressed: () {},
              position: _ButtonPosition.first,
            ),
            _ActionButton(
              icon: 'sell',
              label: 'Sell',
              onPressed: () {},
              position: _ButtonPosition.middle,
            ),
            _ActionButton(
              icon: 'pay',
              label: 'Pay',
              onPressed: () {},
              position: _ButtonPosition.middle,
            ),
            _ActionButton(
              icon: 'swap',
              label: 'Swap',
              onPressed: () {},
              position: _ButtonPosition.last,
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.position,
  });

  final String icon;
  final String label;
  final Function onPressed;
  final _ButtonPosition position;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: position == _ButtonPosition.first
          ? CornerRadius.defaultRadius
          : Radius.zero,
      topRight: position == _ButtonPosition.last
          ? CornerRadius.defaultRadius
          : Radius.zero,
      bottomLeft: position == _ButtonPosition.first
          ? CornerRadius.defaultRadius
          : Radius.zero,
      bottomRight: position == _ButtonPosition.last
          ? CornerRadius.defaultRadius
          : Radius.zero,
    );

    return InkWell(
      onTap: () => onPressed(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: radius,
          color: context.colour.onPrimary,
        ),
        child: Column(
          spacing: 8,
          children: [
            Image.asset(icon, height: 20, width: 20),
            BBText(
              label,
              style: context.font.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
