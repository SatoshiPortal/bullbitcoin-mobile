import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:flutter/material.dart';

class BottomNavbar extends StatelessWidget {
  const BottomNavbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 27, top: 11),
      color: context.colour.onPrimary,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BottomNavButton(
            icon: 'bitcoin',
            label: 'Bitcoin',
            onPressed: () {},
            selected: true,
          ),
          _BottomNavButton(
            icon: 'fiat',
            label: 'Fiat',
            onPressed: () {},
            selected: false,
          ),
        ],
      ),
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.selected,
  });

  final String icon;
  final String label;
  final Function onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? context.colour.primary : context.colour.outline;

    return InkWell(
      onTap: () => onPressed(),
      child: Column(
        children: [
          Image.asset(
            'assets/icons/$icon.png',
            width: 24,
            height: 24,
            color: color,
          ),
          const SizedBox(height: 8),
          BBText(
            label,
            style: context.font.labelLarge,
          ),
        ],
      ),
    );
  }
}
