import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/home/presentation/blocs/home_bloc.dart';
import 'package:bb_mobile/features/home/ui/widgets/eye_toggle.dart';
import 'package:bb_mobile/features/home/ui/widgets/home_fiat_balance.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/settings/ui/widgets/superuser_tap_unlocker.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/ui/components/cards/action_card.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:gif/gif.dart';
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

class _UI extends StatefulWidget {
  const _UI();

  @override
  State<_UI> createState() => _UIState();
}

class _UIState extends State<_UI> {
  late Image image;

  @override
  void initState() {
    image = Image.asset(Assets.images2.bgRed.path, fit: BoxFit.fitHeight);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Transform.rotate(angle: 3.141, child: image),
        const _Amounts(),
        const Positioned(top: 54, left: 0, right: 0, child: _TopNav()),
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
            _BtcTotalAmt(),
            Gap(16),
            EyeToggle(),
            Spacer(),
          ],
        ),
        Gap(12),
        _FiatAmt(),
      ],
    );
  }
}

class _BtcTotalAmt extends StatelessWidget {
  const _BtcTotalAmt();

  @override
  Widget build(BuildContext context) {
    final btcTotal = context.select(
      (HomeBloc bloc) => bloc.state.totalBalance(),
    );

    return CurrencyText(
      btcTotal,
      showFiat: false,
      style: context.font.displaySmall,
      color: context.colour.onPrimary,
    );
  }
}

class _FiatAmt extends StatelessWidget {
  const _FiatAmt();

  @override
  Widget build(BuildContext context) {
    final totalBal = context.select(
      (HomeBloc bloc) => bloc.state.totalBalance(),
    );

    return HomeFiatBalance(balanceSat: totalBal);
  }
}

class _TopNav extends StatelessWidget {
  const _TopNav();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const Gap(8),
        IconButton(
          onPressed: () {
            context.read<HomeBloc>().add(const CheckAllWarnings());
          },
          visualDensity: VisualDensity.compact,
          iconSize: 24,
          color: context.colour.onPrimary,
          icon: const Icon(Icons.bar_chart, blendMode: BlendMode.overlay),
        ),
        const Gap(24 + 42),
        const Spacer(),
        SuperuserTapUnlocker(
          tapsReachedMessageBackgroundColor: theme.colorScheme.primary,
          child: const _BullLogo(),
        ),
        const Spacer(),
        const Gap(20),
        IconButton(
          onPressed: () {
            context.pushNamed(TransactionsRoute.transactions.name);
          },
          visualDensity: VisualDensity.compact,
          color: context.colour.onPrimary,
          iconSize: 24,
          icon: const Icon(Icons.history),
        ),
        const Gap(8),

        InkWell(
          onTap: () => context.pushNamed(SettingsRoute.settings.name),
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
    final syncing = context.select(
      (HomeBloc homeBloc) => homeBloc.state.isSyncing,
    );

    if (!syncing) {
      return InkWell(
        onTap: () {
          context.read<HomeBloc>().add(const HomeRefreshed());
        },
        child: Image.asset(
          Assets.images2.bbLogoSmall.path,
          width: 32,
          height: 32,
        ),
      ).animate(delay: 300.ms).fadeIn();
    }

    return Gif(
      image: AssetImage(Assets.images2.bbSync.path),
      autostart: Autostart.loop,
      height: 32,
      width: 32,
    );
  }
}
