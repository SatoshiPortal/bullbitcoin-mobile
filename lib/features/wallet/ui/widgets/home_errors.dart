import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/features/electrum_settings/public/electrum_settings_facade.dart';
import 'package:bb_mobile/features/tor_settings/public/tor_settings_facade.dart';
import 'package:bb_mobile/features/wallet/domain/entity/warning.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
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
      buildWhen: (previous, current) => previous.warnings != current.warnings,
      builder: (context, state) {
        final serverWarning = state.warnings;

        if (serverWarning.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(left: 13.0, right: 13, top: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
