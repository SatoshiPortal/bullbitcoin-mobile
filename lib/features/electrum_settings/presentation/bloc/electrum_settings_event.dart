part of 'electrum_settings_bloc.dart';

sealed class ElectrumSettingsEvent {
  const ElectrumSettingsEvent();
}

class LoadServers extends ElectrumSettingsEvent {}

class ElectrumServerProviderChanged extends ElectrumSettingsEvent {
  final ElectrumServerProvider type;
  ElectrumServerProviderChanged(this.type);
}

class ConfigureLiquidSettings extends ElectrumSettingsEvent {
  const ConfigureLiquidSettings();
}

class ConfigureBitcoinSettings extends ElectrumSettingsEvent {
  const ConfigureBitcoinSettings();
}

class UpdateCustomServerMainnet extends ElectrumSettingsEvent {
  final String customServer;
  UpdateCustomServerMainnet({required this.customServer});
}

class UpdateCustomServerTestnet extends ElectrumSettingsEvent {
  final String customServer;
  UpdateCustomServerTestnet({required this.customServer});
}

class UpdateElectrumAdvancedOptions extends ElectrumSettingsEvent {
  final int? stopGap;
  final int? retry;
  final int? timeout;

  const UpdateElectrumAdvancedOptions({this.stopGap, this.retry, this.timeout});
}

class ToggleSelectedProvider extends ElectrumSettingsEvent {
  final ElectrumServerProvider provider;
  ToggleSelectedProvider(this.provider);
}

class ToggleValidateDomain extends ElectrumSettingsEvent {
  const ToggleValidateDomain();
}

class ToggleTestnet extends ElectrumSettingsEvent {
  const ToggleTestnet();
}

class CheckServerStatus extends ElectrumSettingsEvent {
  final Network network;
  const CheckServerStatus({required this.network});
}

class SetupBlockchain extends ElectrumSettingsEvent {
  const SetupBlockchain();
}

class SaveElectrumServerChanges extends ElectrumSettingsEvent {
  const SaveElectrumServerChanges();
}

class ToggleCustomServerActive extends ElectrumSettingsEvent {
  final Network network;
  final bool isActive;
  ToggleCustomServerActive({required this.network, required this.isActive});
}

// Custom server toggle - as used in the bloc
class ToggleCustomServer extends ElectrumSettingsEvent {
  final bool isCustomSelected;
  ToggleCustomServer({required this.isCustomSelected});
}

// Default server preset toggle - as used in the bloc
class ToggleDefaultServerProvider extends ElectrumSettingsEvent {
  final DefaultElectrumServerProvider preset;
  ToggleDefaultServerProvider({required this.preset});
}

/// Event to set a server as primary after successful connection
class SetPrimaryServer extends ElectrumSettingsEvent {
  final ElectrumServer server;
  const SetPrimaryServer({required this.server});
}

/// Event to reorder servers and update their priorities
class ReorderServers extends ElectrumSettingsEvent {
  final int oldIndex;
  final int newIndex;
  final Network network;

  const ReorderServers({
    required this.oldIndex,
    required this.newIndex,
    required this.network,
  });
}

/// Event to delete a custom server
class DeleteCustomServer extends ElectrumSettingsEvent {
  final ElectrumServer server;
  const DeleteCustomServer({required this.server});
}
