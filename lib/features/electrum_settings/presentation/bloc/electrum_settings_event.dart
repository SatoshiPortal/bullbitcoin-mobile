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
  ConfigureLiquidSettings();
}

class ConfigureBitcoinSettings extends ElectrumSettingsEvent {
  ConfigureBitcoinSettings();
}

class OnElectrumServerSettingsClicked extends ElectrumSettingsEvent {}

class UpdateCustomServerMainnet extends ElectrumSettingsEvent {
  final String customServer;
  UpdateCustomServerMainnet(this.customServer);
}

class UpdateCustomServerTestnet extends ElectrumSettingsEvent {
  final String customServer;
  UpdateCustomServerTestnet(this.customServer);
}

class UpdateElectrumAdvancedOptions extends ElectrumSettingsEvent {
  final ElectrumAdvancedOptions advancedOptions;
  UpdateElectrumAdvancedOptions(this.advancedOptions);
}

class ToggleSelectedProvider extends ElectrumSettingsEvent {
  final ElectrumServerProvider provider;
  ToggleSelectedProvider(this.provider);
}

class ToggleValidateDomain extends ElectrumSettingsEvent {}

class CheckServerStatus extends ElectrumSettingsEvent {
  final ElectrumServerProvider electrumServerProvider;
  final Network network;
  CheckServerStatus(this.electrumServerProvider, this.network);
}

class SetupBlockchain extends ElectrumSettingsEvent {
  final ElectrumServerProvider electrumServerProvider;
  final Network network;
  SetupBlockchain(this.electrumServerProvider, this.network);
}

class SaveElectrumServerChanges extends ElectrumSettingsEvent {}
