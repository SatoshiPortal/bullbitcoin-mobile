import 'package:bb_mobile/_ui/bottom_sheet.dart';
import 'package:bb_mobile/create/bloc/create_cubit.dart';
import 'package:bb_mobile/create/page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class CreateWalletConfirmPopUp extends StatelessWidget {
  const CreateWalletConfirmPopUp({super.key});

  static Future showPopup(BuildContext context) async {
    final cubit = context.read<CreateWalletCubit>();
    return showBBBottomSheet(
      context: context,
      child: BlocProvider.value(
        value: cubit,
        child: const CreateWalletConfirmPopUp(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const _Screen();
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap(16),
        const CreateWalletPopupTitle(),
        const Gap(40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            children: [
              for (final text in approveText) ApproveText(text: text),
              const Gap(16),
              const InfoText(),
              const Gap(48),
              const Center(child: CreateWalletConfirmButton()),
            ],
          ),
        ),
        const Gap(24),
      ],
    );
  }
}

final approveText = [
  'If I lose my 12 words, I will not be able to recover access to the Bitcoin Wallet.',
  'Without a passphrase, anybody with access to my 12 words can steal my bitcoins.',
  'If I lose my passphrase, I will not be able ro recover access to the Bitcoin Wallet.',
  'Anybody with both the passphrase and the 12 words can steal my bitcoins.',
];
