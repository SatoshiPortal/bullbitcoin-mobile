import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:bb_mobile/gen/assets.gen.dart';
import 'package:flutter/material.dart';

class BottomNavbar extends StatelessWidget {
  const BottomNavbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 27, top: 11),
      color: context.colour.onPrimary,
      height: 100,
      child: Row(
        // mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BottomNavButton(
            icon: Assets.icons.btc.path,
            label: 'Wallet',
            onPressed: () {},
            selected: true,
          ),
          _BottomNavButton(
            icon: Assets.icons.dollar.path,
            label: 'Exchange',
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

    return Expanded(
      child: InkWell(
        onTap: () => onPressed(),
        child: Column(
          children: [
            Image.asset(
              icon,
              width: 24,
              height: 24,
              color: color,
            ),
            const SizedBox(height: 8),
            BBText(
              label,
              style: context.font.labelLarge,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}
