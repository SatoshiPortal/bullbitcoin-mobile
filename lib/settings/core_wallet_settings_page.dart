import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:bb_mobile/_repository/app_wallets_repository.dart';
import 'package:bb_mobile/_repository/network_repository.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class CoreWalletSettingsPage extends StatelessWidget {
  const CoreWalletSettingsPage({super.key});

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
                SecureBitcoinWallet(),
                Gap(8),
                InstantPaymentsWallet(),
                // Gap(8),
                // InformationButton(),
                Gap(8),
                _ButtonList(),
                // ColdcardWallet(),
                // Gap(80),
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
      text: 'Wallet settings',
    );
  }
}

class SecureBitcoinWallet extends StatelessWidget {
  const SecureBitcoinWallet({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      label: 'Secure Bitcoin wallet',
      onPressed: () {
        // final walletBlocs = context.read<HomeBloc>().state.walletBlocs;
        final network = context.read<NetworkRepository>().getBBNetwork;
        final wallet =
            context.read<AppWalletsRepository>().getMainSecureWallet(network);
        // final walletBloc = walletBlocs
        //     ?.where((w) => w.state.wallet?.network == network && w.state.wallet?.type == BBWalletType.secure)
        //     .first;
        context.push('/wallet-settings', extra: wallet!.id);
      },
    );
  }
}

class InstantPaymentsWallet extends StatelessWidget {
  const InstantPaymentsWallet({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      label: 'Instant Payments wallet',
      onPressed: () {
        final network = context.read<NetworkRepository>().getBBNetwork;
        final wallet =
            context.read<AppWalletsRepository>().getMainInstantWallet(network);
        context.push('/wallet-settings', extra: wallet!.id);
      },
    );
  }
}

class _ButtonList extends StatefulWidget {
  const _ButtonList();

  @override
  State<_ButtonList> createState() => _ButtonListState();
}

class _ButtonListState extends State<_ButtonList> {
  List<Wallet> wallets = [];

  @override
  void initState() {
    final network = context.read<NetworkRepository>().getBBNetwork;
    wallets =
        context.read<AppWalletsRepository>().walletNotMainFromNetwork(network);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (wallets.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final wallet in wallets) ...[
          BBButton.textWithStatusAndRightArrow(
            label: wallet.name ?? 'Wallet',
            onPressed: () {
              context.push('/wallet-settings', extra: wallet.id);
            },
          ),
          const Gap(8),
        ],
      ],
    );
  }
}

class ColdcardWallet extends StatelessWidget {
  const ColdcardWallet({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      label: 'Coldcard wallet',
      onPressed: () {
        final network = context.read<NetworkRepository>().getBBNetwork;
        final wallet =
            context.read<AppWalletsRepository>().getColdCardWallet(network);
        context.push('/wallet-settings', extra: wallet.id);
      },
    );
  }
}

class InformationButton extends StatelessWidget {
  const InformationButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      label: 'Information',
      onPressed: () {
        context.push('/information');
      },
    );
  }
}
