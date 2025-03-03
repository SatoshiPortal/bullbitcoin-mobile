import 'dart:ui';

import 'package:bb_mobile/_ui/components/cards/price_card.dart';
import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:bb_mobile/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class HomeTopSection extends StatelessWidget {
  const HomeTopSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      // fit: StackFit.expand,
      children: [
        Image.asset(
          Assets.images2.bgRed.path,
        ),
        const _Amounts(),
        const _TopNav(),
      ],
    );
  }
}

class _Amounts extends StatelessWidget {
  const _Amounts();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Spacer(),
            Gap(31),
            Gap(24),
            PriceCard(text: '0 BTC'),
            Gap(24),
            _EyeToggle(),
            Spacer(),
          ],
        ),
        _FiatAmt(),
      ],
    );
  }
}

class _EyeToggle extends StatelessWidget {
  const _EyeToggle();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: context.colour.surfaceBright,
        ),
        color: context.colour.scrim,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
        child: Icon(
          Icons.remove_red_eye,
          color: context.colour.onPrimary,
          size: 20,
        ),
      ),
    );
  }
}

class _FiatAmt extends StatelessWidget {
  const _FiatAmt();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: context.colour.surfaceDim,
        ),
        color: context.colour.surfaceDim,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2.4, sigmaY: 2.4),
        child: BBText(
          '\$0.0 CAD',
          style: context.font.displaySmall,
          color: context.colour.onPrimary,
        ),
      ),
    );
  }
}

class _TopNav extends StatelessWidget {
  const _TopNav();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () {},
          iconSize: 24,
          icon: const Icon(
            Icons.bar_chart,
          ),
        ),
        const Gap(24 + 16),
        const Spacer(),
        const _BullLogo(),
        const Spacer(),
        IconButton(
          onPressed: () {},
          iconSize: 24,
          icon: const Icon(Icons.history),
        ),
        const Gap(16),
        IconButton(
          onPressed: () {},
          iconSize: 24,
          icon: const Icon(Icons.settings),
        ),
      ],
    );
  }
}

class _BullLogo extends StatelessWidget {
  const _BullLogo();

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
