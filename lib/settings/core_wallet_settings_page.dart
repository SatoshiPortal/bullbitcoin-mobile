import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
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
                Gap(8),
                _ButtonList(),
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
        // final walletBlocs = context.read<HomeCubit>().state.walletBlocs;
        final network = context.read<NetworkCubit>().state.getBBNetwork();
        final walletBloc =
            context.read<HomeCubit>().state.getMainSecureWallet(network);
        // final walletBloc = walletBlocs
        //     ?.where((w) => w.state.wallet?.network == network && w.state.wallet?.type == BBWalletType.secure)
        //     .first;
        context.push('/wallet-settings', extra: walletBloc);
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
        final network = context.read<NetworkCubit>().state.getBBNetwork();
        final walletBloc =
            context.read<HomeCubit>().state.getMainInstantWallet(network);
        context.push('/wallet-settings', extra: walletBloc);
      },
    );
  }
}

class _ButtonList extends StatelessWidget {
  const _ButtonList();

  @override
  Widget build(BuildContext context) {
    final network = context.select((NetworkCubit _) => _.state.getBBNetwork());
    final walletBlocs = context.select(
      (HomeCubit _) => _.state.walletBlocsNotMainFromNetwork(network),
    );

    if (walletBlocs.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final walletBloc in walletBlocs) ...[
          BBButton.textWithStatusAndRightArrow(
            label: walletBloc.state.wallet?.name ?? 'Wallet',
            onPressed: () {
              context.push('/wallet-settings', extra: walletBloc);
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
        final walletBlocs = context.read<HomeCubit>().state.walletBlocs;
        final network = context.read<NetworkCubit>().state.testnet
            ? BBNetwork.Testnet
            : BBNetwork.Mainnet;
        final walletBloc = walletBlocs
            ?.where(
              (w) =>
                  w.state.wallet?.network == network &&
                  w.state.wallet?.type == BBWalletType.coldcard,
            )
            .first;
        context.push('/wallet-settings', extra: walletBloc);
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
