import 'package:bb_mobile/_model/currency.dart';
import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:bb_mobile/_pkg/extensions.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network/popup.dart';
import 'package:bb_mobile/network_fees/popup.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/settings/lighting.dart';
import 'package:extra_alignments/extra_alignments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: locator<SettingsCubit>(),
      child: const _Screen(),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: const SettingsAppBar(),
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              children: [
                Gap(8),
                Currencyx(),
                Gap(8),
                Units(),
                Gap(8),
                TestNetButton(),
                Gap(8),
                DefaultRBFToggle(),
                Gap(8),
                ChangePin(),
                Gap(8),
                SelectFeesButton(fromSettings: true),
                Gap(8),
                BroadCastButton(),
                Gap(8),
                NetworkButton(),
                Gap(8),
                LightingButton(),
                Gap(80),
                CenterLeft(
                  child: BBText.bodySmall(
                    'Version $bbVersion',
                    isBold: true,
                  ),
                ),
                Gap(24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsAppBar extends StatelessWidget {
  const SettingsAppBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BBAppBar(
      buttonKey: UIKeys.settingsBackButton,
      onBack: () {
        context.pop();
      },
      text: 'Settings',
    );
  }
}

class Currencyx extends StatelessWidget {
  const Currencyx({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = context.select((SettingsCubit x) => x.state.currency);
    final currencies = context.select((SettingsCubit x) => x.state.currencyList ?? []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.body(
          'Currency',
        ),
        const Gap(4),
        SizedBox(
          height: 60,
          child: InputDecorator(
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(40.0),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Currency>(
                items: currencies
                    .map(
                      (c) => DropdownMenuItem<Currency>(
                        value: c,
                        child: BBText.body(c.getFullName()),
                      ),
                    )
                    .toList(),
                value: currency,
                onChanged: (c) {
                  if (c != null) context.read<SettingsCubit>().changeCurrency(c);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class Units extends StatelessWidget {
  const Units({super.key});

  @override
  Widget build(BuildContext context) {
    final isSats = context.select((SettingsCubit x) => x.state.unitsInSats);

    return Row(
      children: [
        const BBText.body(
          'Display unit in sats',
        ),
        const Spacer(),
        Switch(
          value: isSats,
          onChanged: (e) {
            context.read<SettingsCubit>().toggleUnitsInSats();
          },
        ),
      ],
    );
  }
}

class Translate extends StatelessWidget {
  const Translate({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.select((SettingsCubit x) => x.state.language ?? 'en');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BBText.body(
          'settings.language.title'.translate,
        ),
        const Gap(4),
        InputDecorator(
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(40.0),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton(
              items: ['en', 'fr']
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: BBText.body(e),
                    ),
                  )
                  .toList(),
              value: lang,
              onChanged: (e) {
                context.read<SettingsCubit>().changeLanguage(e!);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class ChangePin extends StatelessWidget {
  const ChangePin({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      label: 'Change PIN',
      onPressed: () {
        context.push('/change-pin');
      },
    );
  }
}

class BroadCastButton extends StatelessWidget {
  const BroadCastButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      label: 'Broadcast transaction',
      onPressed: () {
        context.push('/broadcast');
        // BroadcasePage.openPopUp(context);
      },
    );
  }
}

class DefaultRBFToggle extends StatelessWidget {
  const DefaultRBFToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final rbf = context.select((SettingsCubit x) => x.state.defaultRBF);

    return Row(
      children: [
        // const Gap(8),
        const BBText.body(
          'Default RBF',
        ),
        const Spacer(),
        Switch(
          value: rbf,
          onChanged: (e) {
            context.read<SettingsCubit>().toggleDefaultRBF();
          },
        ),
      ],
    );
  }
}

class LightingButton extends StatelessWidget {
  const LightingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      label: 'Lighting',
      onPressed: () {
        LightingPopUp.openPopUp(context);
      },
    );
  }
}

class TestNetButton extends StatelessWidget {
  const TestNetButton({super.key});

  @override
  Widget build(BuildContext context) {
    final testnet = context.select((NetworkCubit _) => _.state.testnet);

    return Row(
      children: [
        // const Gap(8),
        const BBText.body(
          'Testnet mode',
        ),
        const Spacer(),
        Switch(
          key: UIKeys.settingsTestnetSwitch,
          value: testnet,
          onChanged: (e) {
            context.read<NetworkCubit>().toggleTestnet();
          },
        ),
      ],
    );
  }
}

class NetworkButton extends StatelessWidget {
  const NetworkButton({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedNetwork = context.select((NetworkCubit _) => _.state.getNetwork());
    if (selectedNetwork == null) return const SizedBox.shrink();
    final err = context.select((NetworkCubit _) => _.state.errLoadingNetworks);

    return Column(
      children: [
        BBButton.textWithStatusAndRightArrow(
          label: 'Electrum Server',
          onPressed: () {
            NetworkPopup.openPopUp(context);
          },
        ),
        // InkWell(
        //   onTap: () {
        //     NetworkPopup.openPopUp(context);
        //   },
        //   child: Row(
        //     children: [
        //       BBButton.text(
        //         onPressed: () {
        //           NetworkPopup.openPopUp(context);
        //         },
        //         label: 'Electrum server',
        //       ),
        //       const Gap(6),
        //       FaIcon(
        //         FontAwesomeIcons.angleRight,
        //         size: 14,
        //         color: context.colour.secondary,
        //       ),
        //     ],
        //   ),
        // ),
        if (err.isNotEmpty)
          BBText.errorSmall(
            err,
          ),
      ],
    );
  }
}
