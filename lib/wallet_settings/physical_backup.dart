import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/word_grid.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bb_mobile/wallet_settings/bloc/backup_settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class InfoRead extends Cubit<bool> {
  InfoRead() : super(false);

  void read() => emit(true);
  void unread() => emit(false);
}

class PhysicalBackupPage extends StatefulWidget {
  const PhysicalBackupPage({
    super.key,
    required this.wallet,
  });

  final String wallet;

  @override
  State<PhysicalBackupPage> createState() => _PhysicalBackupPageState();
}

class _PhysicalBackupPageState extends State<PhysicalBackupPage> {
  late WalletBloc walletBloc;
  late BackupSettingsCubit backupSettings;
  @override
  void initState() {
    walletBloc = createOrRetreiveWalletBloc(widget.wallet);
    backupSettings = createBackupSettingsCubit(widget.wallet);

    backupSettings.loadBackupForVerification();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: walletBloc),
        BlocProvider(create: (BuildContext context) => backupSettings),
        BlocProvider.value(value: InfoRead()),
      ],
      child: const _Screen(),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  Future<bool> _handleNavigationCleanup(
    BuildContext context,
    bool state,
  ) async {
    try {
      if (state) {
        context.read<InfoRead>().unread();
      }
      await context.read<BackupSettingsCubit>().clearSensitive();

      if (!context.mounted) return false;
      context.pop();
      //TODO: context.go('/home');
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InfoRead, bool>(
      listener: (context, state) {
        // debugPrint('InfoRead state changed to: $state');
      },
      builder: (context, state) {
        return PopScope(
          onPopInvokedWithResult: (didPop, _) async {
            if (!didPop) {
              final result = await _handleNavigationCleanup(context, state);
              if (!result) return;
            }
          },
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              elevation: 0,
              flexibleSpace: BBAppBar(
                text: '',
                onBack: () async {
                  await _handleNavigationCleanup(context, state);
                },
              ),
            ),
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: state
                  ? const BackupScreen(key: ValueKey('backup'))
                  : const BackUpInfoScreen(key: ValueKey('info')),
            ),
          ),
        );
      },
    );
  }
}

class BackUpInfoScreen extends StatelessWidget {
  const BackUpInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lastPhysicalBackupTested = context.select(
      (WalletBloc cubit) => cubit.state.wallet.lastPhysicalBackupTested,
    );

    final hasPassphrase = context
        .select((WalletBloc cubit) => cubit.state.wallet.hasPassphrase());
    final instructions = backupInstructions(hasPassphrase);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 16.0, left: 24, right: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BBText.titleLarge(
              'Backup best practices',
              isBold: true,
            ),
            const Gap(8),
            if (lastPhysicalBackupTested != null) ...[
              BBText.bodySmall(
                'Last backup tested on ${lastPhysicalBackupTested.toLocal()}',
              ),
              const Gap(8),
            ],
            const Gap(24),
            for (final i in instructions) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Gap(8),
                  const Padding(
                    padding: EdgeInsets.only(top: 4.0),
                    child: Icon(Icons.circle, color: Colors.black),
                  ),
                  const Gap(8),
                  Expanded(child: BBText.body(i)),
                ],
              ),
              const Gap(16),
            ],
            const Gap(24),
            Center(
              child: SizedBox(
                width: 250,
                child: BBButton.big(
                  filled: true,
                  onPressed: () {
                    context.read<InfoRead>().read();
                  },
                  label: 'Backup',
                ),
              ),
            ),
            const Gap(60),
          ],
        ),
      ),
    );
  }
}

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mnemonic = context.select(
      (BackupSettingsCubit cubit) => cubit.state.mnemonic,
    );

    final password = context.select(
      (BackupSettingsCubit cubit) => cubit.state.password,
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
            MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.noScaling),
              child: WordGrid(mne: mnemonic),
            ),
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
            // Center(
            //   child: SizedBox(
            //     width: 200,
            //     child: BBButton.big2(
            //       onPressed: () {
            //         context.pop();
            //       },
            //       label: 'Okay',
            //     ),
            //   ),
            // ),
            const Gap(24),
            Center(
              child: SizedBox(
                width: 250,
                child: BBButton.big(
                  filled: true,
                  onPressed: () {
                    context
                        // ..pop()
                        .push(
                      '/wallet-settings/backup-settings/physical/test-backup',
                      extra: context.read<WalletBloc>().state.wallet.id,
                      // (
                      //   context.read<Wallet>(),
                      //   context.read<BackupSettingsCubit>(),
                      // ),
                    );
                    // context.pop();
                    // TestBackupScreen.openPopup(context);
                  },
                  // centered: true,
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
