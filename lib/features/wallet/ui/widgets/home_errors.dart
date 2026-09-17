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
import 'package:bull_ui/bull_ui.dart' show BullCarousel, Gap;
import 'package:go_router/go_router.dart';

class HomeWarnings extends StatelessWidget {
  const HomeWarnings({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletBloc, WalletState>(
      buildWhen: (previous, current) =>
          previous.hasNoBackup() != current.hasNoBackup() ||
          previous.loadFailure != current.loadFailure ||
          previous.warnings != current.warnings,
      builder: (context, state) {
        // The legacy-storage cohort used to suppress this warning, since
        // they were shown a blocking overlay instead. That cohort and
        // its overlay are gone.
        final showBackupWarning = state.hasNoBackup();
        final loadFailure = state.loadFailure;

        // Every error is shown, swipeable, instead of one hiding another.
        // A sync failure and a server warning often come together (offline,
        // an unreachable server) but say different things: the balances are
        // stale, and which server failed with its own remedy.
        final errorCards = [
          for (final warning in state.warnings)
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
          // A failed load used to be silent: the skeleton simply vanished
          // and the home screen showed 0 sats and no wallets, which reads
          // as an empty wallet rather than an error (#1895).
          // No settings link: a sync can fail in swaps or Silent Payments as
          // well as on a server, and a storage failure is local, so pointing
          // at the electrum settings could not help. A server outage has its
          // own card above, with its remedy.
          if (loadFailure != null)
            InfoCard(
              title: loadFailure.toTranslated(context),
              description: context.loc.walletLoadFailedRetryHint,
              tagColor: context.appColors.error,
              bgColor: context.appColors.errorContainer,
            ),
        ];

        if (!showBackupWarning && errorCards.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(left: 13.0, right: 13, top: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (errorCards.isNotEmpty) BullCarousel(children: errorCards),
              if (showBackupWarning) ...[
                if (errorCards.isNotEmpty) const Gap(5),
                BackupCard(
                  onTap: () => context.pushNamed(
                    BackupSettingsSubroute.backupOptions.name,
                  ),
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
