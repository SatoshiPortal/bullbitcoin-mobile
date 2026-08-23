import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/cards/backup_card.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/electrum_settings/public/electrum_settings_facade.dart';
import 'package:bb_mobile/features/tor_settings/public/tor_settings_facade.dart';
import 'package:bb_mobile/features/wallet/domain/entity/warning.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
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
          previous.warnings != current.warnings,
      builder: (context, state) {
        final showBackupWarning =
            state.hasNoBackup() && !state.isOnLegacyStorage;
        final serverWarning = state.warnings;

        if (!showBackupWarning && serverWarning.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(left: 13.0, right: 13, top: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                      const ElectrumSettingsFacade().settingsRouteName,
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

String homeWarningTitle(BuildContext context, WalletWarning warning) =>
    switch (warning.action) {
      WalletWarningAction.torSettings =>
        context.loc.torSettingsExternalProxyUnavailable,
      WalletWarningAction.electrumSettings => warning.title,
    };

String homeWarningDescription(BuildContext context, WalletWarning warning) =>
    switch (warning.action) {
      WalletWarningAction.torSettings =>
        context.loc.torSettingsExternalProxyUnavailableDescription,
      WalletWarningAction.electrumSettings => warning.description,
    };
