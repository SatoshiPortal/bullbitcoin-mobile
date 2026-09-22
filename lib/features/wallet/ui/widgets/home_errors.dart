import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/cards/backup_card.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/electrum_settings/public/electrum_settings_facade.dart';
import 'package:bb_mobile/features/tor_settings/public/tor_settings_facade.dart';
import 'package:bb_mobile/features/wallet/domain/entity/warning.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/presentation/wallet_failure_l10n.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:go_router/go_router.dart';

class HomeWarnings extends StatelessWidget {
  const HomeWarnings({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletBloc, WalletState>(
      buildWhen: (previous, current) =>
          previous.hasNoBackup() != current.hasNoBackup() ||
          previous.isOnLegacyStorage != current.isOnLegacyStorage ||
          previous.loadFailure != current.loadFailure ||
          previous.warnings != current.warnings,
      builder: (context, state) {
        final showBackupWarning =
            state.hasNoBackup() && !state.isOnLegacyStorage;
        final serverWarning = state.warnings;
        final loadFailure = state.loadFailure;

        if (!showBackupWarning &&
            serverWarning.isEmpty &&
            loadFailure == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(left: 13.0, right: 13, top: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A failed load used to be silent: the skeleton simply vanished
              // and the home screen showed 0 sats and no wallets, which reads
              // as an empty wallet rather than an error (#1895).
              // Only a sync failure is worth sending to the server settings.
              // A storage or unexpected failure is local: pointing at electrum
              // there would be a remedy that cannot possibly help.
              if (loadFailure != null)
                if (loadFailure is WalletSyncFailure)
                  InfoCard(
                    title: loadFailure.toTranslated(context),
                    description: context.loc.walletWarningElectrumAction,
                    tagColor: context.appColors.error,
                    bgColor: context.appColors.errorContainer,
                    onTap: () => context.pushNamed(
                      locator<ElectrumSettingsFacade>().settingsRouteName,
                    ),
                  )
                else
                  InfoCard(
                    title: loadFailure.toTranslated(context),
                    description: context.loc.walletLoadFailedRetryHint,
                    tagColor: context.appColors.error,
                    bgColor: context.appColors.errorContainer,
                  ),
              if (showBackupWarning)
                BackupCard(
                  onTap: () => context.pushNamed(
                    BackupSettingsSubroute.backupOptions.name,
                  ),
                ),

              for (final warning in serverWarning) ...[
                const Gap(5),
                InfoCard(
                  title: homeWarningTitle(context, warning),
                  description: homeWarningDescription(context, warning),
                  tagColor: context.appColors.error,
                  bgColor: context.appColors.errorContainer,
                  onTap: () => context.pushNamed(switch (warning.action) {
                    WalletWarningAction.electrumSettings =>
                      locator<ElectrumSettingsFacade>().settingsRouteName,
                    WalletWarningAction.torSettings =>
                      const TorSettingsFacade().settingsRouteName,
                  }),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// The warning carries a reason, not a sentence: the wording is chosen here so
/// it goes through `context.loc` and is translated like everything else.
String homeWarningTitle(
  BuildContext context,
  WalletWarning warning,
) => switch (warning.action) {
  WalletWarningAction.torSettings =>
    context.loc.torSettingsExternalProxyUnavailable,
  WalletWarningAction.electrumSettings => switch (warning.reason) {
    ElectrumServerDown.bitcoin => context.loc.walletWarningElectrumBitcoinDown,
    ElectrumServerDown.liquid => context.loc.walletWarningElectrumLiquidDown,
    ElectrumServerDown.both => context.loc.walletWarningElectrumBothDown,
  },
};

String homeWarningDescription(BuildContext context, WalletWarning warning) =>
    switch (warning.action) {
      WalletWarningAction.torSettings =>
        context.loc.torSettingsExternalProxyUnavailableDescription,
      WalletWarningAction.electrumSettings =>
        context.loc.walletWarningElectrumAction,
    };
