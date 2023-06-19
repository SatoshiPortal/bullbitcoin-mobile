import 'package:bb_mobile/_model/currency.dart';
import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:bb_mobile/_pkg/extensions.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/fees.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/settings/broadcast.dart';
import 'package:bb_mobile/settings/electrum.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Gap(16),
              const Units(),
              const Gap(16),
              const Currencyx(),
              // const Gap(16),
              // const Translate(),
              const Gap(16),
              const SelectFeesButton(fromSettings: true),
              const ChangePin(),
              const BroadCastButton(),
              const Gap(8),
              Divider(
                color: context.colour.onBackground.withOpacity(0.2),
              ),
              const Gap(8),
              const TestNetButton(),
              const NetworkButton(),
              const Gap(24),
            ],
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
    final currencies =
        context.select((SettingsCubit x) => x.state.currencyList ?? []);
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
                  if (c != null)
                    context.read<SettingsCubit>().changeCurrency(c);
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
    return InkWell(
      onTap: () {
        context.push('/change-pin');
      },
      child: Row(
        children: [
          BBButton.text(
            onPressed: () {
              context.push('/change-pin');
            },
            label: 'Change PIN',
          ),
          const Gap(6),
          FaIcon(
            FontAwesomeIcons.angleRight,
            size: 14,
            color: context.colour.secondary,
          )
        ],
      ),
    );
  }
}

class ImportWalletButton extends StatelessWidget {
  const ImportWalletButton({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        context.push('/import');
      },
      child: Row(
        children: [
          BBButton.text(
            onPressed: () {
              context.push('/import');
            },
            label: 'Import Wallet',
          ),
          const Gap(6),
          FaIcon(
            FontAwesomeIcons.angleRight,
            size: 14,
            color: context.colour.secondary,
          )
        ],
      ),
    );
  }
}

class BroadCastButton extends StatelessWidget {
  const BroadCastButton({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        BroadcasePopUp.openPopUp(context);
      },
      child: Row(
        children: [
          BBButton.text(
            onPressed: () {
              BroadcasePopUp.openPopUp(context);
            },
            label: 'Broadcast Transaction',
          ),
          const Gap(6),
          FaIcon(
            FontAwesomeIcons.angleRight,
            size: 14,
            color: context.colour.secondary,
          )
        ],
      ),
    );
  }
}
