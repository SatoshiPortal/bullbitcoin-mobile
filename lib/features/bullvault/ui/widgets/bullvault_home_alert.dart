import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_home_alert_cubit.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

final class BullVaultHomeAlert extends StatefulWidget {
  final List<Wallet> wallets;

  const BullVaultHomeAlert({super.key, required this.wallets});

  @override
  State<BullVaultHomeAlert> createState() => _BullVaultHomeAlertState();
}

final class _BullVaultHomeAlertState extends State<BullVaultHomeAlert> {
  @override
  void initState() {
    super.initState();
    context.read<BullVaultHomeAlertCubit>().load(widget.wallets);
  }

  @override
  void didUpdateWidget(BullVaultHomeAlert oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.wallets, widget.wallets)) {
      context.read<BullVaultHomeAlertCubit>().load(widget.wallets);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletId = context.watch<BullVaultHomeAlertCubit>().state;
    if (walletId == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 13, right: 13, top: 13),
      child: InfoCard(
        title: context.loc.bullVaultPreviousFundsAction,
        description: context.loc.bullVaultPreviousVaultMigrating,
        tagColor: context.appColors.error,
        bgColor: context.appColors.errorContainer,
        onTap: () => context.pushNamed(
          BullVaultFacade.settingsRouteName,
          pathParameters: {'walletId': walletId},
          extra: context.loc.bullVaultSettingsTitle,
        ),
      ),
    );
  }
}
