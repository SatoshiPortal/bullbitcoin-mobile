import 'package:bb_mobile/_pkg/extensions.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/create.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/repository.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/headers.dart';
import 'package:bb_mobile/_ui/word_grid.dart';
import 'package:bb_mobile/create/bloc/create_cubit.dart';
import 'package:bb_mobile/create/bloc/state.dart';
import 'package:bb_mobile/create/confirm_popup.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class CreateWalletPage extends StatelessWidget {
  const CreateWalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    final createWallet = CreateWalletCubit(
      settingsCubit: locator<SettingsCubit>(),
      walletSensCreate: locator<WalletSensitiveCreate>(),
      hiveStorage: locator<HiveStorage>(),
      secureStorage: locator<SecureStorage>(),
      walletRepository: locator<WalletRepository>(),
      walletSensRepository: locator<WalletSensitiveRepository>(),
      networkCubit: locator<NetworkCubit>(),
    );

    return BlocProvider.value(
      value: createWallet,
      child: BlocListener<CreateWalletCubit, CreateWalletState>(
        listenWhen: (previous, current) => previous.saved != current.saved,
        listener: (context, state) async {
          if (state.saved) {
            if (state.savedWallet == null) return;
            locator<HomeCubit>().addWallet(state.savedWallet!);
            await Future.delayed(500.milliseconds);
            locator<HomeCubit>().moveToLastWallet();
            // await Future.delayed(300.milliseconds);
            context.go('/home');
          }
        },
        child: const _Screen(),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: BBAppBar(
          text: 'create.title'.translate,
          onBack: () {
            context.pop();
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const Gap(24),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
              ),
              child: BBText.bodySmall(
                'create.disclaimer'.translate,
                isBold: true,
              ),
            ),
            const Gap(24),
            const Words(),
            const Gap(32),
            const CreateWalletPassField(),
            const Gap(12),
            const CreateWalletLabel(),
            const Gap(40),
            const CreateWalletCreateButton(),
            const Gap(80),
          ],
        ),
      ),
    );
  }
}

class Words extends StatelessWidget {
  const Words({super.key});

  @override
  Widget build(BuildContext context) {
    final mne = context.select((CreateWalletCubit cubit) => cubit.state.mnemonic ?? []);
    return WordGrid(mne: mne);
  }
}

class CreateWalletPopupTitle extends StatelessWidget {
  const CreateWalletPopupTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return const BBHeader.popUpCenteredText(text: 'Protect Your Money');
  }
}

class CreateWalletPassField extends HookWidget {
  const CreateWalletPassField({super.key});

  @override
  Widget build(BuildContext context) {
    final text = context.select((CreateWalletCubit x) => x.state.passPhrase);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: BBText.body(
              'create.passphrase.title'.translate,
            ),
          ),
          const Gap(8),
          BBTextInput.big(
            value: text,
            maxLength: 32,
            hint: 'Enter passphrase',
            onChanged: (t) {
              context.read<CreateWalletCubit>().passPhraseChanged(t);
            },
          ),
        ],
      ),
    );
  }
}

class CreateWalletLabel extends StatelessWidget {
  const CreateWalletLabel();

  @override
  Widget build(BuildContext context) {
    final text = context.select((CreateWalletCubit cubit) => cubit.state.walletLabel ?? '');

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: BBTextInput.big(
        value: text,
        onChanged: (value) => context.read<CreateWalletCubit>().walletLabelChanged(value),
        hint: 'Label your wallet',
      ),
    );
  }
}

class CreateWalletConfirmButton extends StatelessWidget {
  const CreateWalletConfirmButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BBButton.bigRed(
            filled: true,
            onPressed: () {
              context.read<CreateWalletCubit>().confirmClicked();
            },
            label: 'Confirm',
          ),
          const Gap(16),
          BBButton.text(
            onPressed: () {
              Navigator.of(context).pop();
            },
            label: 'Back',
            centered: true,
          ),
          const Gap(32),
        ],
      ),
    );
  }
}

class ApproveText extends StatelessWidget {
  const ApproveText({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaIcon(FontAwesomeIcons.circle, color: context.colour.surface),
          const Gap(16),
          Flexible(
            child: BBText.body(
              text,
            ),
          ),
        ],
      ),
    );
  }
}

class InfoText extends StatelessWidget {
  const InfoText({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        FaIcon(
          FontAwesomeIcons.solidLightbulb,
        ),
        Gap(16),
        Flexible(
          child: BBText.title(
            'Pro-tip: Store your passphrase and 12 words separately.',
          ),
        ),
      ],
    );
  }
}

class CreateWalletCreateButton extends StatelessWidget {
  const CreateWalletCreateButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.7,
      child: BBButton.bigRed(
        onPressed: () {
          CreateWalletConfirmPopUp.showPopup(context);
        },
        label: 'create.button'.translate,
      ),
    );
  }
}
