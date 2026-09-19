import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_recovery_notice_cubit.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bull_ui/bull_ui.dart' show BullInfoCard;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class BullVaultRecoveryNotice extends StatelessWidget {
  const BullVaultRecoveryNotice({super.key});
  @override
  Widget build(BuildContext context) {
    final notice = context.watch<BullVaultRecoveryNoticeCubit>().state;
    if (notice == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 13, right: 13, top: 13),
      child: BullInfoCard(
        tagColor: context.appColors.primary,
        bgColor: context.appColors.surfaceContainer,
        title: context.loc.bullVaultRestoreCompleteTitle,
        description: notice.label.isEmpty
            ? context.loc.bullVaultWalletLabel
            : notice.label,
        onTap: () {
          context.pushNamed(
            BullVaultFacade.settingsRouteName,
            pathParameters: {'walletId': notice.walletId},
          );
          context.read<BullVaultRecoveryNoticeCubit>().opened(notice.walletId);
        },
      ),
    );
  }
}
