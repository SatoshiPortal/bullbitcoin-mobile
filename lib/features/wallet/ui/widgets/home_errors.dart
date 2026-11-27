import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:backups/backups.dart';
import 'package:network/network.dart';
import 'package:overview/overview.dart';
import 'package:swap_feature/swap_feature.dart' show SwapNavigation;
import 'package:bb_mobile/features/wallet/domain/entity/warning.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/presentation/wallet_failure_l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeWarnings extends StatelessWidget {
  const HomeWarnings({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletBloc, WalletState>(
      buildWhen: (previous, current) =>
          previous.hasNoBackup() != current.hasNoBackup() ||
          previous.loadFailure != current.loadFailure ||
          previous.warnings != current.warnings ||
          previous.swapServerUnreachable != current.swapServerUnreachable,
      builder: (context, state) {
        final loadFailure = state.loadFailure;
        return HomeWarningCarousel(
          network: [
            for (final warning in state.warnings)
              (
                copy: (
                  title: homeWarningTitle(context, warning),
                  description: homeWarningDescription(context, warning),
                ),
                destination: switch (warning.action) {
                  WalletWarningAction.electrumSettings =>
                    HomeWarningDestination.electrum,
                  WalletWarningAction.torSettings => HomeWarningDestination.tor,
                },
              ),
          ],
          swap: state.swapServerUnreachable
              ? (
                  title: context.loc.walletWarningSwapServerUnreachable,
                  description: context.loc.walletWarningSwapServerAction,
                )
              : null,
          load: loadFailure == null
              ? null
              : (
                  title: loadFailure.toTranslated(context),
                  description: context.loc.walletLoadFailedRetryHint,
                ),
          backup: state.hasNoBackup()
              ? BackupCard(
                  icon: AssetImage(Assets.misc.passwordbook.path),
                  onTap: () => BackupsNavigation.start(context),
                )
              : null,
          onOpen: (destination) => switch (destination) {
            HomeWarningDestination.electrum => NetworkNavigation.open(
              context,
              section: NetworkSection.electrum,
            ),
            HomeWarningDestination.tor => NetworkNavigation.open(
              context,
              section: NetworkSection.tor,
            ),
            HomeWarningDestination.swap => SwapNavigation.openSettings(context),
          },
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
