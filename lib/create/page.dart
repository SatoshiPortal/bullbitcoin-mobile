import 'package:bb_mobile/_pkg/extensions.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/create_sensitive.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/controls.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/headers.dart';
import 'package:bb_mobile/_ui/page_template.dart';
import 'package:bb_mobile/_ui/word_grid.dart';
import 'package:bb_mobile/create/bloc/create_cubit.dart';
import 'package:bb_mobile/create/bloc/state.dart';
import 'package:bb_mobile/create/confirm_popup.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:extra_alignments/extra_alignments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class CreateWalletPage extends StatelessWidget {
  const CreateWalletPage({super.key, this.mainWallet = false});

  final bool mainWallet;

  @override
  Widget build(BuildContext context) {
    final createWallet = CreateWalletCubit(
      walletSensCreate: locator<WalletSensitiveCreate>(),
      walletsStorageRepository: locator<WalletsStorageRepository>(),
      walletSensRepository: locator<WalletSensitiveStorageRepository>(),
      networkCubit: locator<NetworkCubit>(),
      walletCreate: locator<WalletCreate>(),
      bdkSensitiveCreate: locator<BDKSensitiveCreate>(),
      lwkSensitiveCreate: locator<LWKSensitiveCreate>(),
      mainWallet: mainWallet,
    );

    return BlocProvider.value(
      value: ScrollCubit(),
      child: BlocProvider.value(
        value: createWallet,
        child: BlocListener<CreateWalletCubit, CreateWalletState>(
          listenWhen: (previous, current) => previous.saved != current.saved,
          listener: (context, state) async {
            if (state.saved) {
              if (state.savedWallets == null) return;
              locator<HomeCubit>().getWalletsFromStorage();
              // final wallets = state.savedWallets!;
              // locator<HomeCubit>().addWallets(wallets);
              // await Future.delayed(500.milliseconds);
              // locator<HomeCubit>().changeMoveToIdx(wallets.first);
              // await Future.delayed(300.milliseconds);
              context.go('/home');
            }
          },
          child: const _Screen(),
        ),
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
          text: 'Backup Your Wallet'.translate,
          onBack: () {
            context.pop();
          },
        ),
      ),
      body: StackedPage(
        bottomChild: const CreateWalletCreateButton(),
        child: SingleChildScrollView(
          controller: context.read<ScrollCubit>().state,
          child: Column(
            children: [
              const Gap(24),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                ),
                child: BBText.bodySmall(
                  "Write down these 12 words somewhere safe, on a piece of paper or engraved in metal. You'll need them if you lose your phone or access to the Bull Bitcoin app. Don't store them on a phone or computer."
                      .translate,
                  isBold: true,
                ),
              ),
              const Gap(24),
              const Words(),
              const Gap(32),
              const CreateWalletPassField(),
              const Gap(12),
              const CreateWalletLabel(),
              // const Gap(40),
              const Gap(100),

              // const CreateWalletCreateButton(),
              // const Gap(80),
            ],
          ),
        ),
      ),
    );
  }
}

class Words extends StatelessWidget {
  const Words({super.key});

  @override
  Widget build(BuildContext context) {
    final mne =
        context.select((CreateWalletCubit cubit) => cubit.state.mnemonic ?? []);
    final loading = context
        .select((CreateWalletCubit cubit) => cubit.state.creatingNmemonic);

    if (loading)
      return const Padding(
        padding: EdgeInsets.only(left: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CenterLeft(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(),
              ),
            ),
            Gap(8),
            BBText.bodySmall('Generating mnemonic...'),
          ],
        ),
      );

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
              'Passphrase (optional)'.translate,
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
    final mainWallet =
        context.select((CreateWalletCubit cubit) => cubit.state.mainWallet);
    if (mainWallet) return const SizedBox.shrink();

    final text = context
        .select((CreateWalletCubit cubit) => cubit.state.walletLabel ?? '');
    final err =
        context.select((CreateWalletCubit cubit) => cubit.state.errSaving);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BBTextInput.big(
            value: text,
            onChanged: (value) =>
                context.read<CreateWalletCubit>().walletLabelChanged(value),
            onEnter: () async {
              await Future.delayed(500.ms);
              context.read<ScrollCubit>().state.animateTo(
                    context.read<ScrollCubit>().state.position.maxScrollExtent,
                    duration: 500.milliseconds,
                    curve: Curves.linear,
                  );
            },
            hint: 'Label your wallet',
          ),
          if (err.isNotEmpty) ...[
            const Gap(8),
            Center(child: BBText.error(err)),
          ],
        ],
      ),
    );
  }
}

class CreateWalletConfirmButton extends StatelessWidget {
  const CreateWalletConfirmButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // width: MediaQuery.of(context).size.width * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: BBButton.big(
              filled: true,
              onPressed: () {
                context.read<CreateWalletCubit>().confirmClicked();
              },
              label: 'Confirm',
            ),
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
    return BBButton.big(
      onPressed: () async {
        await context.read<CreateWalletCubit>().checkWalletLabel();
        final err = context.read<CreateWalletCubit>().state.errSaving;
        if (err.isNotEmpty) return;
        CreateWalletConfirmPopUp.showPopup(context);
      },
      label: 'Create Wallet'.translate,
    );
  }
}
