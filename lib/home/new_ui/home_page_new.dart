import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_bloc.dart';
import 'package:bb_mobile/home/new_ui/assets.gen.dart';
import 'package:bb_mobile/home/new_ui/new_ui.dart';
import 'package:bb_mobile/network/bloc/network_bloc.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class HomePageNew extends StatelessWidget {
  const HomePageNew({super.key});

  @override
  Widget build(BuildContext context) {
    final colours = AppColours.lightColourScheme;
    final fonts = AppFonts.textTheme;

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorScheme: colours,
        canvasColor: colours.surface,
        scaffoldBackgroundColor: colours.secondaryFixed,
        fontFamily: fonts.fontFamily,
        textTheme: fonts.textTheme,
      ),
      child: const _HomeScreen(),
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // return BlocProvider<HomeBloc>(
    //   create: (context) => locator<HomeBloc>()..add(const HomeStarted()),
    //   child: BlocListener<SettingsCubit, Settings?>(
    //     listenWhen: (previous, current) =>
    //         previous?.environment != current?.environment,
    //     listener: (context, settings) {
    //       context.read<HomeBloc>().add(const HomeStarted());
    //     },
    //     child: const _Screen(),
    //   ),
    // );
    return const _Screen();
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      bottomNavigationBar: BottomNavbar(),
      body: Column(
        children: [
          HomeTopSection(),
          HomeWalletCards(),
          // Spacer(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 13.0),
            child: HomeBottomButtons(),
          ),
          Gap(16),
        ],
      ),
    );
  }
}

class HomeWalletCards extends StatelessWidget {
  const HomeWalletCards({super.key});

  @override
  Widget build(BuildContext context) {
    final _ = context.select((HomeBloc x) => x.state.updated);

    final network = context.select((NetworkBloc x) => x.state.getBBNetwork());
    final wallets =
        context.select((HomeBloc x) => x.state.walletsFromNetwork(network));

    // final card1 =
    //     context.select((HomeBloc bloc) => bloc.state.defaultBitcoinWallet);
    // final card2 =
    //     context.select((HomeBloc bloc) => bloc.state.defaultLiquidWallet);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(13.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final w in wallets) ...[
                WalletCard(
                  tagColor: context.colour.tertiary,
                  title: w.name ?? w.sourceFingerprint,
                  description: w.getWalletTypeStr(),
                  wallet: w,
                  onTap: () {
                    context.push('/wallet', extra: w.id);
                  },
                ),
                const Gap(8),
              ],
              // if (card1 != null)
              //   WalletCard(
              //     tagColor: context.colour.onTertiary,
              //     title: 'Secure Bitcoin wallet',
              //     description: 'Bitcoin network',
              //     wallet: card1,
              //     onTap: () {},
              //   ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    final network = context.select((NetworkBloc x) => x.state.getBBNetwork());
    final sats = context.select(
      (HomeBloc x) => x.state.totalBalanceSats(network),
    );

    final balance = context.select(
      (CurrencyCubit x) => x.state.getAmountInUnits(sats, removeText: true),
    );
    final unit = context.select(
      (CurrencyCubit x) => x.state.getUnitString(),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Gap(32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            const Gap(31),
            const Gap(32),
            PriceCard(text: '$balance $unit'),
            const Gap(32),
            const _EyeToggle(),
            const Spacer(),
          ],
        ),
        const Gap(12),
        const _FiatAmt(),
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
    final network = context.select((NetworkBloc x) => x.state.getBBNetwork());
    final sats = context.select(
      (HomeBloc x) => x.state.totalBalanceSats(network),
    );

    final fiatCurrency =
        context.select((CurrencyCubit x) => x.state.defaultFiatCurrency);

    final fiatAmt = context
        .select((NetworkBloc x) => x.state.calculatePrice(sats, fiatCurrency));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: context.colour.surfaceDim,
        ),
        color: context.colour.surfaceDim,
      ),
      child: BBBText(
        '\$$fiatAmt ${fiatCurrency?.name}',
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
          visualDensity: VisualDensity.compact,
          iconSize: 24,
          color: context.colour.onPrimary,
          icon: const Icon(Icons.bar_chart),
          onPressed: () {},
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
          onTap: () {
            context.push('/settings');
          },
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

class HomeBottomButtons extends StatelessWidget {
  const HomeBottomButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: BBBButton.big(
            iconData: Icons.arrow_downward,
            label: 'Receive',
            iconFirst: true,
            onPressed: () {
              context.push('/receive');
            },
            bgColor: context.colour.secondary,
            textColor: context.colour.onPrimary,
          ),
        ),
        const Gap(4),
        Expanded(
          child: BBBButton.big(
            iconData: Icons.crop_free,
            label: 'Send',
            iconFirst: true,
            onPressed: () {
              context.push('/send');
            },
            bgColor: context.colour.secondary,
            textColor: context.colour.onPrimary,
          ),
        ),
      ],
    );
  }
}

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
            BBBText(
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
