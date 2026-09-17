import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/loading/status_screen.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/router.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class VaultCreatedPage extends StatelessWidget {
  const VaultCreatedPage({super.key});

  @override
  Widget build(BuildContext context) {
    // The package said `WordsOnly`: the vault format carries the words alone,
    // and this wallet has a passphrase. Decision of 2026-09-15 — the format
    // does not change, the user is told. This is where.
    final passphraseExcluded = context.select<RecoverBullBloc, bool>(
      (bloc) => bloc.state.vaultExcludesPassphrase,
    );
    return StatusScreen(
      title: context.loc.recoverbullEncryptedVaultCreated,
      description: context.loc.recoverbullTestBackupDescription,
      extras: [
        if (passphraseExcluded)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.appColors.surface,
                border: Border.all(color: context.appColors.error),
                borderRadius: BorderRadius.circular(8),
              ),
              child: BBText(
                context.loc.recoverbullVaultPassphraseNotIncluded,
                style: context.font.bodyMedium,
                color: context.appColors.error,
                textAlign: .center,
                maxLines: 6,
              ),
            ),
          ),
      ],
      isLoading: false,
      buttonText: context.loc.recoverbullTestRecovery,
      onTap: () => context.goNamed(
        RecoverBullRoute.recoverbullFlows.name,
        extra: RecoverBullFlowsExtra(
          flow: RecoverBullFlow.testVault,
          vault: null,
        ),
      ),
    );
  }
}
