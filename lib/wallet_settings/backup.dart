import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/word_grid.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bb_mobile/wallet_settings/bloc/wallet_settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BackupPage extends StatelessWidget {
  const BackupPage({super.key, required this.walletBloc, required this.walletSettings});

  final WalletBloc walletBloc;
  final WalletSettingsCubit walletSettings;

  @override
  Widget build(BuildContext context) {
    walletSettings.loadBackupClicked();

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: walletBloc),
        BlocProvider.value(value: walletSettings),
      ],
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: BBAppBar(
            text: 'Backup',
            onBack: () {
              context.pop();
            },
          ),
        ),
        body: const BackupScreen(),
      ),
    );
  }
}

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mnemonic = context.select(
      (WalletSettingsCubit cubit) => cubit.state.mnemonic,
    );

    final password = context.select(
      (WalletSettingsCubit cubit) => cubit.state.password,
    );

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: BBText.bodySmall(
                'Write down these 12/24 words somewhere safe, on a piece of paper or engraved in metal. You’ll need them if you lose your phone or access to the Bull Bitcoin app. Don’t store them on a phone or computer.',
              ),
            ),
            const Gap(8),
            if (mnemonic.length == 12) WordGrid(mne: mnemonic) else WordGrid(mne: mnemonic),
            if (password.isNotEmpty) ...[
              const Gap(24),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: BBText.bodySmall(
                  'This wallet backup is protected by an addditional BIP39 passphrase. If you lose the passphrase, you will not be able to recover access to the wallet. Write down your passphrase and your backup words separately: anybody that has both your passphrase and your backup words can steal your Bitcoin.',
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: BBText.body(
                  'Passphrase: $password',
                ),
              ),
            ] else ...[
              const Gap(24),
              const Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: BBText.bodySmall(
                  'This wallet backup is not protected by an additional BIP39 passphrase. Anybody that finds your backup words can steal your Bitcoin. You can add a passphrase when creating a new wallet',
                ),
              ),
            ],
            const Gap(48),
            Center(
              child: SizedBox(
                width: 200,
                child: BBButton.bigRed(
                  onPressed: () {
                    context.pop();
                  },
                  label: 'Okay',
                ),
              ),
            ),
            const Gap(24),
            Center(
              child: SizedBox(
                width: 200,
                child: BBButton.text(
                  onPressed: () {
                    context
                      ..pop()
                      ..push(
                        '/wallet-settings/test-backup',
                        extra: (
                          context.read<WalletBloc>(),
                          context.read<WalletSettingsCubit>(),
                        ),
                      );
                    // context.pop();
                    // TestBackupScreen.openPopup(context);
                  },
                  centered: true,
                  label: 'Test backup',
                ),
              ),
            ),
            const Gap(48),
          ],
        ),
      ),
    );
  }
}
