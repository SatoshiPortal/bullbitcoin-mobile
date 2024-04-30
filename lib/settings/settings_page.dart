import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
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
    //const latestVersion = bbVersion;
    const latestVersion = '0.2.0-1';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: const SettingsAppBar(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Gap(8),
                const BitcoinSettingsButton(),
                const Gap(8),
                const ApplicationSettingsButton(),
                const Gap(8),
                const WalletSettingsButton(),
                const Gap(8),
                const NewWalletButton(),
                const Gap(24),
                const Center(
                  child: BBText.bodySmall(
                    'App Version: $bbVersion',
                    isBold: true,
                  ),
                ),
                const Gap(8),
                if (bbVersion != latestVersion)
                  BBButton.big(
                    label: 'Update app',
                    onPressed: () {
                      print('Update app');
                    },
                  ),
                const Gap(24),
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

class WalletSettingsButton extends StatelessWidget {
  const WalletSettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      label: 'Wallet settings',
      onPressed: () {
        context.push('/core-wallet-settings');
      },
    );
  }
}

class NewWalletButton extends StatelessWidget {
  const NewWalletButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      label: 'Create, import or recover wallet',
      onPressed: () {
        context.push('/import');
      },
    );
  }
}

class ApplicationSettingsButton extends StatelessWidget {
  const ApplicationSettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      label: 'Application settings',
      onPressed: () {
        context.push('/application-settings');
      },
    );
  }
}

class BitcoinSettingsButton extends StatelessWidget {
  const BitcoinSettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      label: 'Bitcoin settings',
      onPressed: () {
        context.push('/bitcoin-settings');
      },
    );
  }
}
