import 'package:bb_mobile/_repository/app_wallets_repository.dart';
import 'package:bb_mobile/_repository/wallet_service.dart';
import 'package:bb_mobile/recoverbull/bloc/backup_settings_cubit.dart';
import 'package:bb_mobile/recoverbull/bloc/backup_settings_state.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TestBackupListener extends StatelessWidget {
  const TestBackupListener({super.key, required this.child});

  final Widget child;
  @override
  Widget build(BuildContext context) {
    return BlocListener<BackupSettingsCubit, BackupSettingsState>(
      listenWhen: (previous, current) =>
          previous.backupTested != current.backupTested,
      listener: (context, state) {
        if (!state.backupTested) return;

        final wallet = context.read<WalletBloc>().state.wallet;

        final walletService = context
            .read<AppWalletsRepository>()
            .findWalletServiceWithSameFngr(wallet);
        if (walletService == null) return;

        final w = walletService.wallet.copyWith(
          physicalBackupTested: true,
          lastPhysicalBackupTested: DateTime.now(),
        );

        walletService.updateWallet(
          w,
          updateTypes: [
            UpdateWalletTypes.settings,
          ],
        );
      },
      child: child,
    );
  }
}
