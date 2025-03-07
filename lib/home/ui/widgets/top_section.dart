import 'package:bb_mobile/_ui/components/cards/action_card.dart';
import 'package:bb_mobile/_ui/components/cards/price_card.dart';
import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:bb_mobile/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class HomeTopSection extends StatelessWidget {
  const HomeTopSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 264 + 78 + 46,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 264 + 78,
                // color: Colors.red,
                child: _UI(),
              ),
              // const Gap(40),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 13.0),
              child: ActionCard(),
            ),
          ),
        ],
      ),
    );
  }
}

class _UI extends StatelessWidget {
  const _UI();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Transform.rotate(
          angle: 3.141,
          child: Image.asset(
            Assets.images2.bgRed.path,
            fit: BoxFit.fitHeight,
          ),
        ),
        const _Amounts(),
        const Positioned(
          top: 54,
          left: 0,
          right: 0,
          child: _TopNav(),
        ),
      ],
    );
  }
}

class _Amounts extends StatelessWidget {
  const _Amounts();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Gap(32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Spacer(),
            Gap(31),
            Gap(32),
            PriceCard(text: '0 BTC'),
            Gap(32),
            _EyeToggle(),
            Spacer(),
          ],
        ),
        Gap(12),
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
      child: Icon(
        Icons.remove_red_eye,
        color: context.colour.onPrimary,
        size: 20,
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
      child: BBText(
        '\$0.0 CAD',
        style: context.font.bodyLarge,
        color: context.colour.onPrimary,
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
        const Gap(8),
        IconButton(
          onPressed: () {
            context.pop();
          },
          visualDensity: VisualDensity.compact,
          iconSize: 24,
          color: context.colour.onPrimary,
          icon: const Icon(Icons.bar_chart),
        ),
        const Gap(24 + 42),
        const Spacer(),
        const _BullLogo(),
        const Spacer(),
        const Gap(12),
        IconButton(
          onPressed: () {},
          visualDensity: VisualDensity.compact,
          color: context.colour.onPrimary,
          iconSize: 24,
          icon: const Icon(Icons.history),
        ),
        const Gap(8),

        InkWell(
          onTap: () {},
          child: Image.asset(
            Assets.icons.settingsLine.path,
            width: 24,
            height: 24,
            color: context.colour.onPrimary,
          ),
        ),
        // IconButton(
        //   visualDensity: VisualDensity.compact,
        //   onPressed: () {},
        //   iconSize: 24,
        //   color: context.colour.onPrimary,
        //   icon: const Icon(Icons.bolt),
        // ),
        const Gap(16),
      ],
    );
  }
}

class _BullLogo extends StatelessWidget {
  const _BullLogo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      Assets.images2.bbLogoSmall.path,
      height: 32,
      // width: 40,
    );
  }
}
