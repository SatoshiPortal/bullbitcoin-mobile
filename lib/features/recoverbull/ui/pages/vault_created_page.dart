import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/loading/status_screen.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class VaultCreatedPage extends StatelessWidget {
  const VaultCreatedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StatusScreen(
      title: context.loc.recoverbullEncryptedVaultCreated,
      description: context.loc.recoverbullTestBackupDescription,
      isLoading: false,
      buttonText: context.loc.recoverbullTestRecovery,
      onTap: () async {
        final returnToCaller = context
            .read<RecoverBullBloc>()
            .state
            .returnToCaller;
        final seedFingerprint = context
            .read<RecoverBullBloc>()
            .state
            .seedFingerprint;
        if (!returnToCaller) {
          context.goNamed(
            RecoverBullRoute.recoverbullFlows.name,
            extra: RecoverBullFlowsExtra(
              flow: RecoverBullFlow.testVault,
              vault: null,
            ),
          );
          return;
        }
        final completed = await context.pushNamed<bool>(
          RecoverBullRoute.recoverbullFlows.name,
          extra: RecoverBullFlowsExtra(
            flow: RecoverBullFlow.testVault,
            vault: null,
            returnToCaller: true,
            seedFingerprint: seedFingerprint,
          ),
        );
        if (completed == true && context.mounted) context.pop(true);
      },
    );
  }
}
