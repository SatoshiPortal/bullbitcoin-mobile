import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bb_mobile/wallet_settings/bloc/backup_settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BackupSettings extends StatefulWidget {
  const BackupSettings({
    super.key,
    required this.wallet,
  });

  final String wallet;

  @override
  State<BackupSettings> createState() => _BackupSettingsState();
}

class _BackupSettingsState extends State<BackupSettings> {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(
          value: createOrRetreiveWalletBloc(widget.wallet),
        ),
        BlocProvider(
          create: (BuildContext context) =>
              createBackupSettingsCubit(widget.wallet),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: BBAppBar(
            onBack: () {
              context.pop();
            },
            text: 'Backup settings',
          ),
        ),
        body: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Gap(16),
              _Screen(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();
  @override
  Widget build(BuildContext context) {
    final watchOnly =
        context.select((WalletBloc cubit) => cubit.state.wallet.watchOnly());
    final isPhysicalBackupTested =
        context.select((WalletBloc x) => x.state.wallet.physicalBackupTested);
    final isVaultBackupTested =
        context.select((WalletBloc x) => x.state.wallet.vaultBackupTested);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colour.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: NewColours.lightGray.withAlpha(50),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: NewColours.lightGray.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BBText.titleLarge(
            "Backup settings",
            isBold: true,
          ),
          const Gap(10),
          if (!watchOnly) ...[
            BBButton.textWithStatus(
              label: "Physical backup",
              onPressed: () {},
              statusText: isPhysicalBackupTested ? 'Tested' : 'Not Tested',
              isGreen: isPhysicalBackupTested,
              isRed: !isPhysicalBackupTested,
            ),
          ],
          BBButton.textWithStatus(
            label: "Encrypted vault",
            onPressed: () {},
            statusText: isVaultBackupTested ? 'Tested' : 'Not Tested',
            isGreen: isVaultBackupTested,
            isRed: !isVaultBackupTested,
          ),
          BBButton.withColour(
            label: "Start backup",
            onPressed: () => {
              context.push(
                '/wallet-settings/backup-settings/backup-options',
                extra: context.read<WalletBloc>().state.wallet.id,
              ),
            },
            fillWidth: true,
            center: true,
          ),
          const Gap(20),
          BBButton.withColour(
            label: "Recover or test backup",
            onPressed: () {
              context.push(
                '/wallet-settings/backup-settings/recover-options',
                extra: context.read<WalletBloc>().state.wallet.id,
              );
            },
            fillWidth: true,
            center: true,
          ),
        ],
      ),
    );
  }
}

class RecoverOptionsScreen extends StatelessWidget {
  const RecoverOptionsScreen({super.key, required this.wallet});
  final String wallet;
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class BackupOptionsScreen extends StatelessWidget {
  const BackupOptionsScreen({super.key, required this.wallet});
  final String wallet;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: BBAppBar(
          onBack: () => context.pop(),
          text: '',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const BBText.titleLarge(
              'Backup you wallet',
              isBold: true,
              fontSize: 25,
            ),
            const Gap(10),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Without a backup, you',
                    style: context.font.bodySmall!.copyWith(
                      fontSize: 12,
                    ),
                  ),
                  TextSpan(
                    text: ' will ',
                    style: context.font.bodySmall!.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  TextSpan(
                    text:
                        'eventually lose access to your money. It is critically important to do a backup.',
                    style: context.font.bodySmall!.copyWith(
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(20),
            _renderBackupSetting(
              title: 'Encrypted vault (quick and easy)',
              description:
                  'Your backup is encrypted with a secure key that cannot be cracked, and uploaded to your cloud account. The key to unlock your vault is stored in an anonymous password manager and accessible with your PIN.',
              onTap: () => context.push(
                '/wallet-settings/backup-settings/encrypted',
                extra: wallet,
              ),
            ),
            const Gap(20),
            _renderBackupSetting(
              title: 'Physical backup (take your time)',
              description:
                  'You have to write down 12 words on a piece of paper or engrave it in metal. Make sure not to lose it. If anybody ever finds those 12 words, they can steal your Bitcoin.',
              onTap: () async => context.push(
                '/wallet-settings/backup-settings/physical',
                extra: wallet,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _renderBackupSetting({
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: NewColours.lightGray.withAlpha(50),
              blurRadius: 30,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: NewColours.lightGray.withAlpha(100)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BBText.title(
                    title,
                    isBold: true,
                  ),
                  const Gap(4),
                  BBText.bodySmall(
                    description,
                    removeColourOpacity: true,
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Icon(
                Icons.arrow_forward_ios,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
