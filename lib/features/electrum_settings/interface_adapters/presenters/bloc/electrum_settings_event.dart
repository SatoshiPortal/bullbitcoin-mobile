part of 'electrum_settings_bloc.dart';

sealed class ElectrumSettingsEvent {
  const ElectrumSettingsEvent();
}

class ElectrumSettingsLoaded extends ElectrumSettingsEvent {
  final bool isLiquid;

  const ElectrumSettingsLoaded({required this.isLiquid});
}

class ElectrumCustomServerAdded extends ElectrumSettingsEvent {
  final String url;

  const ElectrumCustomServerAdded({required this.url});
}

class ElectrumCustomServersPrioritized extends ElectrumSettingsEvent {
  final int movedFromListIndex;
  final int movedToListIndex;

  const ElectrumCustomServersPrioritized({
    required this.movedFromListIndex,
    required this.movedToListIndex,
  });
}

class ElectrumCustomServerDeleted extends ElectrumSettingsEvent {
  final ElectrumServerViewModel server;

  const ElectrumCustomServerDeleted({required this.server});
}

class ElectrumAdvancedOptionsSaved extends ElectrumSettingsEvent {
  final String stopGap;
  final String timeout;
  final String retry;
  final bool validateDomain;
  final String? socks5;

  const ElectrumAdvancedOptionsSaved({
    required this.stopGap,
    required this.timeout,
    required this.retry,
    required this.validateDomain,
    this.socks5,
  });
}

class ElectrumAdvancedOptionsReset extends ElectrumSettingsEvent {
  const ElectrumAdvancedOptionsReset();
}
