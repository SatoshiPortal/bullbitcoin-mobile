import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_home_alert_cubit.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_wallet_settings_cubit.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_home_alert.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_wallet_settings_action.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class BullVaultHomeContribution extends StatelessWidget {
  final List<Wallet> wallets;

  const BullVaultHomeContribution({super.key, required this.wallets});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => locator<BullVaultHomeAlertCubit>(),
    child: BullVaultHomeAlert(wallets: wallets),
  );
}

final class BullVaultWalletSettingsContribution extends StatelessWidget {
  final Wallet wallet;

  const BullVaultWalletSettingsContribution({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => locator<BullVaultWalletSettingsCubit>()..load(wallet.id),
    child: BullVaultWalletSettingsAction(wallet: wallet),
  );
}
