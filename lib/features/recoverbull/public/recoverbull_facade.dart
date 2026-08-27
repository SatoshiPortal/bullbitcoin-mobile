import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/router.dart';
import 'package:bb_mobile/features/recoverbull/ui/widgets/view_vault_key_warning_bottom_sheet.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class RecoverBullFacade {
  const RecoverBullFacade();

  void openSettings(BuildContext context) => context.pushNamed(
    RecoverBullRoute.recoverbullFlows.name,
    extra: RecoverBullFlowsExtra(flow: RecoverBullFlow.settings, vault: null),
  );

  Future<void> openViewVaultKey(BuildContext context) async {
    final confirmed = await ViewVaultKeyWarningBottomSheet.show(context);
    if (confirmed != true || !context.mounted) return;
    openRecoverBullFlow(context, flow: RecoverBullFlow.viewVaultKey);
  }
}
