import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_recovery_notice_cubit.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_recovery_notice.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_home_alert_cubit.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_wallet_settings_cubit.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_home_alert.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_wallet_settings_action.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class BullVaultHomeContribution extends StatelessWidget {
  final List<Wallet> wallets;

  const BullVaultHomeContribution({super.key, required this.wallets});

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => GetIt.I<BullVaultHomeAlertCubit>()),
      BlocProvider.value(value: GetIt.I<BullVaultRecoveryNoticeCubit>()),
    ],
    child: Column(
      children: [
        const BullVaultRecoveryNotice(),
        BullVaultHomeAlert(wallets: wallets),
      ],
    ),
  );
}

final class BullVaultWalletSettingsContribution extends StatelessWidget {
  final Wallet wallet;

  const BullVaultWalletSettingsContribution({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => GetIt.I<BullVaultWalletSettingsCubit>()..load(wallet.id),
    child: BullVaultWalletSettingsAction(wallet: wallet),
  );
}
