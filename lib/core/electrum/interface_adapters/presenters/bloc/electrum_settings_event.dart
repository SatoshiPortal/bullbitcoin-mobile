part of 'electrum_settings_bloc.dart';

sealed class ElectrumSettingsEvent {
  const ElectrumSettingsEvent();
}

class ElectrumSettingsLoaded extends ElectrumSettingsEvent {
  const ElectrumSettingsLoaded();
}

class ElectrumCustomServerAdded extends ElectrumSettingsEvent {
  final String url;
  final bool isLiquid;

  const ElectrumCustomServerAdded({required this.url, required this.isLiquid});
}

class ElectrumCustomServersPrioritized extends ElectrumSettingsEvent {
  final List<ElectrumServerViewModel> servers;
  final bool isLiquid;

  const ElectrumCustomServersPrioritized({
    required this.servers,
    required this.isLiquid,
  });
}

class ElectrumCustomServerDeleted extends ElectrumSettingsEvent {
  final ElectrumServerViewModel server;
  final bool isLiquid;

  const ElectrumCustomServerDeleted({
    required this.server,
    required this.isLiquid,
  });
}

class ElectrumAdvancedOptionsSaved extends ElectrumSettingsEvent {
  final int stopGap;
  final int timeout;
  final int retry;
  final bool validateDomain;
  final String? socks5;
  final bool isLiquid;

  const ElectrumAdvancedOptionsSaved({
    required this.stopGap,
    required this.timeout,
    required this.retry,
    required this.validateDomain,
    this.socks5,
    required this.isLiquid,
  });
}
