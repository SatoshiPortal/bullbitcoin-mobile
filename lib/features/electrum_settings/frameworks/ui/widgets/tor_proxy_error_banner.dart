import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/tor/tor_status.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TorProxyErrorBanner extends StatelessWidget {
  const TorProxyErrorBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final useTorProxy = context.select(
      (TorSettingsCubit cubit) => cubit.state.useTorProxy,
    );
    final torStatus = context.select(
      (TorSettingsCubit cubit) => cubit.state.status,
    );
    final activeOnionServersAreOffline = context.select(
      (ElectrumSettingsBloc bloc) => bloc.state.activeOnionServersAreOffline,
    );
    final isLiquid = context.select(
      (ElectrumSettingsBloc bloc) => bloc.state.isLiquid,
    );

    // Don't show banner if:
    // - Tor is not enabled
    // - Tor proxy is online
    // - The active server set has no onion server or is not fully offline
    // - Only show for Bitcoin (not Liquid)
    if (!useTorProxy ||
        torStatus == TorStatus.online ||
        !activeOnionServersAreOffline ||
        isLiquid) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InfoCard(
        description: context.loc.torSettingsDescDisconnected,
        tagColor: context.appColors.error,
        bgColor: context.appColors.errorContainer,
      ),
    );
  }
}
