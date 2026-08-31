import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_wallet_settings_cubit.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

final class BullVaultWalletSettingsAction extends StatelessWidget {
  final Wallet wallet;

  const BullVaultWalletSettingsAction({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) {
    final details = context.watch<BullVaultWalletSettingsCubit>().state;
    if (details == null) return const SizedBox.shrink();
    final routeWalletId = switch (details.record.status) {
      BullVaultLifecycleStatus.active ||
      BullVaultLifecycleStatus.migrating => details.record.walletId,
      BullVaultLifecycleStatus.pending ||
      BullVaultLifecycleStatus.activating ||
      BullVaultLifecycleStatus.cancelled => details.record.previousVaultId,
    };
    if (routeWalletId == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: BBButton.big(
        label: details.hasPreviousFunds
            ? context.loc.bullVaultPreviousFundsAction
            : context.loc.bullVaultSettingsTitle,
        onPressed: () => context.pushNamed(
          BullVaultFacade.settingsRouteName,
          pathParameters: {'walletId': routeWalletId},
          extra: wallet.displayLabel(context),
        ),
        bgColor: context.appColors.primary,
        textColor: context.appColors.onPrimary,
        iconData: Icons.chevron_right,
      ),
    );
  }
}
