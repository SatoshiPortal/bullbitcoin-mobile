import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/tor/tor_status.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TorProxyErrorBanner extends StatelessWidget {
  const TorProxyErrorBanner({super.key});

  bool _areAllServersOffline(ElectrumSettingsState state) {
    final allServers = [...state.defaultServers, ...state.customServers];

    if (allServers.isEmpty) {
      return false;
    }

    return allServers.every(
      (server) => server.status == ElectrumServerStatus.offline,
    );
  }

  @override
  Widget build(BuildContext context) {
    final electrumState = context.watch<ElectrumSettingsBloc>().state;
    final torState = context.watch<TorSettingsCubit>().state;
    final advancedOptions = electrumState.advancedOptions;

    // Don't show banner if:
    // - Tor is not enabled
    // - Tor proxy is online
    // - Not all servers are offline
    // - Only show for Bitcoin (not Liquid)
    if (advancedOptions == null ||
        !advancedOptions.useTorProxy ||
        torState.status == TorStatus.online ||
        !_areAllServersOffline(electrumState) ||
        electrumState.isLiquid) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InfoCard(
        description:
            'Tor proxy is enabled but cannot connect. Make sure Orbot or similar app is running, or disable Tor proxy in Advanced Options (server will see your IP address).',
        tagColor: context.colour.error,
        bgColor: context.colour.error.withValues(alpha: 0.1),
      ),
    );
  }
}
