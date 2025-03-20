import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:bb_mobile/gen/assets.gen.dart';
import 'package:bb_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

enum _ButtonPosition { first, last, middle }

class ActionCard extends StatelessWidget {
  const ActionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Gap(2),
            Container(
              // padding: const EdgeInsets.all(20),
              height: 70,
              color: context.colour.secondaryFixed,
              // color: Colors.red,
            ),
            // const Gap(2),
          ],
        ),
        const _ActionRow(),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow();

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      color: Colors.transparent,
      child: SizedBox(
        height: 80,
        child: Row(
          children: [
            _ActionButton(
              icon: Assets.icons.btc.path,
              label: 'Buy',
              onPressed: () {
                context.pushNamed(AppRoute.buy.name);
              },
              position: _ButtonPosition.first,
            ),
            const Gap(1),
            _ActionButton(
              icon: Assets.icons.dollar.path,
              label: 'Sell',
              onPressed: () {
                context.pushNamed(AppRoute.sell.name);
              },
              position: _ButtonPosition.middle,
            ),
            const Gap(1),
            _ActionButton(
              icon: Assets.icons.rightArrow.path,
              label: 'Pay',
              onPressed: () {},
              position: _ButtonPosition.middle,
            ),
            const Gap(1),
            _ActionButton(
              icon: Assets.icons.swap.path,
              label: 'Swap',
              onPressed: () {},
              position: _ButtonPosition.last,
            ),
          ],
        ),
      ),
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
    const r = Radius.circular(2);
    final radius = BorderRadius.only(
      topLeft: position == _ButtonPosition.first ? r : Radius.zero,
      topRight: position == _ButtonPosition.last ? r : Radius.zero,
      bottomLeft: position == _ButtonPosition.first ? r : Radius.zero,
      bottomRight: position == _ButtonPosition.last ? r : Radius.zero,
    );

    return Expanded(
      child: InkWell(
        onTap: () => onPressed(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: radius,
            color: context.colour.onPrimary,
          ),
          child: Column(
            spacing: 8,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(icon, height: 24, width: 24),
              BBText(
                label,
                style: context.font.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
