import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:bb_mobile/_pkg/launcher.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
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
    //const latestVersion = bbVersion;
    // const latestVersion = '0.2.0-1';
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
                const BackupBullButton(),
                const Gap(8),
                const RecoverBullButton(),
                const Gap(8),
                const SocialButton(),

                const Gap(24),
                const Center(
                  child: BBText.bodySmall(
                    'App Version: $bbVersion',
                    isBold: true,
                  ),
                ),
                const Gap(40),
                IconButton(
                  onPressed: () {
                    // https://t.me/+gUHV3ZcQ-_RmZDdh
                    locator<Launcher>().launchApp(
                      'https://t.me/+gUHV3ZcQ-_RmZDdh',
                    );
                  },
                  icon: FaIcon(
                    FontAwesomeIcons.telegram,
                    size: 40,
                    color: context.colour.onPrimaryContainer,
                  ),
                ),
                const Gap(4),
                const BBText.bodySmall(
                  'This wallet is currently in BETA.\nReport bugs on our Telegram group.',
                  isBold: true,
                  fontSize: 10,
                  textAlign: TextAlign.center,
                ),
                // if (bbVersion != latestVersion)
                //   BBButton.big(
                //     label: 'Update app',
                //     onPressed: () {},
                //   ),
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
      // label: 'Create, import or recover wallet',
      label: 'Recover wallet',
      onPressed: () {
        context.push('/recover');

        // context.push('/import');
      },
    );
  }
}

class SwapHistoryButton extends StatelessWidget {
  const SwapHistoryButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      // label: 'Create, import or recover wallet',
      label: 'Swap History',
      onPressed: () {
        context.push('/swap-history');

        // context.push('/import');
      },
    );
  }
}

class BackupBullButton extends StatelessWidget {
  const BackupBullButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      label: 'BackupBull',
      onPressed: () {
        final network = context.read<NetworkCubit>().state.getBBNetwork();
        final wallets =
            context.read<HomeCubit>().state.walletBlocsFromNetwork(network);
        context.push('/backupbull', extra: wallets);
      },
    );
  }
}

class RecoverBullButton extends StatelessWidget {
  const RecoverBullButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      label: 'RecoverBull',
      onPressed: () {
        final network = context.read<NetworkCubit>().state.getBBNetwork();
        final wallets =
            context.read<HomeCubit>().state.walletBlocsFromNetwork(network);
        context.push('/recoverbull', extra: wallets);
      },
    );
  }
}

class SocialButton extends StatelessWidget {
  const SocialButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      label: 'Social',
      onPressed: () {
        context.push('/social-settings');
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
