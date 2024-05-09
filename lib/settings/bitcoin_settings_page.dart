import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:bb_mobile/_pkg/extensions.dart';
import 'package:bb_mobile/_pkg/launcher.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/controls.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network/bloc/state.dart';
import 'package:bb_mobile/network/popup.dart';
import 'package:bb_mobile/network_fees/bloc/networkfees_cubit.dart';
import 'package:bb_mobile/network_fees/popup.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:extra_alignments/extra_alignments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BitcoinSettingsPage extends StatelessWidget {
  const BitcoinSettingsPage({super.key});

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
                TestNetButton(),
                Gap(8),
                DefaultRBFToggle(),
                Gap(8),
                Units(),
                Gap(8),
                SelectFeesButton(fromSettings: true),
                Gap(8),
                ElectrumServerButton(),
                Gap(8),
                BroadCastButton(),
                // Gap(8),
                // SearchAddressButton(),
                Gap(8),
                NewWalletButton(),
                // Gap(8),
                // ArchivedWalletsButton(),
                // Gap(8),
                // ReplaceDefaultSeedButton(),
                Gap(80),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SourceCodeButton extends StatelessWidget {
  const SourceCodeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return CenterLeft(
      child: InkWell(
        onTap: () {
          const link = 'https://github.com/SatoshiPortal/bullbitcoin-mobile';
          locator<Launcher>().launchApp(link);
        },
        child: const BBText.bodySmall(
          'Source',
          isBold: true,
          isBlue: true,
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
      text: 'Bitcoin settings',
    );
  }
}

class Units extends StatelessWidget {
  const Units({super.key});

  @override
  Widget build(BuildContext context) {
    final isSats = context.select((CurrencyCubit x) => x.state.unitsInSats);

    return Row(
      children: [
        const BBText.body(
          'Display unit in sats',
        ),
        const Spacer(),
        BBSwitch(
          value: isSats,
          onChanged: (e) {
            context.read<CurrencyCubit>().toggleUnitsInSats();
          },
        ),
      ],
    );
  }
}

class ReplaceDefaultSeedButton extends StatelessWidget {
  const ReplaceDefaultSeedButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      label: 'Replace Default Seed',
      onPressed: () {
        context.push('/replace-default-seed');
      },
    );
  }
}

class ArchivedWalletsButton extends StatelessWidget {
  const ArchivedWalletsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      label: 'Archived wallets',
      onPressed: () {
        context.push('/archived-wallets');
      },
    );
  }
}

class NewWalletButton extends StatelessWidget {
  const NewWalletButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      label: 'Import Bitcoin Wallet',
      onPressed: () {
        context.push('/import');
      },
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
          'Select Language'.translate,
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

class SearchAddressButton extends StatelessWidget {
  const SearchAddressButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      label: 'Search Address',
      onPressed: () {
        context.push('/search-address');
        // BroadcasePage.openPopUp(context);
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
        BBSwitch(
          value: rbf,
          onChanged: (e) {
            context.read<SettingsCubit>().toggleDefaultRBF();
          },
        ),
      ],
    );
  }
}

class TestNetButton extends StatelessWidget {
  const TestNetButton({super.key});

  @override
  Widget build(BuildContext context) {
    final testnet = context.select((NetworkCubit _) => _.state.testnet);

    return BlocListener<NetworkCubit, NetworkState>(
      listenWhen: (previous, current) => previous.testnet != current.testnet,
      listener: (context, state) {
        context.read<NetworkFeesCubit>().loadFees();
        final network = state.getBBNetwork();
        context.read<HomeCubit>().loadWalletsForNetwork(network);
        // context.read<WatchTxsBloc>().add(InitializeSwapWatcher(isTestnet: state.testnet));
      },
      child: Row(
        children: [
          // const Gap(8),
          const BBText.body(
            'Testnet mode',
          ),
          const Spacer(),
          BBSwitch(
            key: UIKeys.settingsTestnetSwitch,
            value: testnet,
            onChanged: (e) {
              context.read<NetworkCubit>().toggleTestnet();
            },
          ),
        ],
      ),
    );
  }
}

class ElectrumServerButton extends StatelessWidget {
  const ElectrumServerButton({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedNetwork =
        context.select((NetworkCubit _) => _.state.getNetwork());
    if (selectedNetwork == null) return const SizedBox.shrink();
    final err = context.select((NetworkCubit _) => _.state.errLoadingNetworks);

    return Column(
      children: [
        BBButton.textWithStatusAndRightArrow(
          label: 'Electrum server',
          onPressed: () {
            NetworkPopup.openPopUp(context);
          },
        ),
        if (err.isNotEmpty)
          BBText.errorSmall(
            err,
          ),
      ],
    );
  }
}
