part of 'electrum_settings_bloc.dart';

sealed class ElectrumSettingsEvent {
  const ElectrumSettingsEvent();
}

class LoadServers extends ElectrumSettingsEvent {}

class ElectrumServerProviderChanged extends ElectrumSettingsEvent {
  final ElectrumServerProvider type;
  ElectrumServerProviderChanged(this.type);
}

class UpdateTempStopGap extends ElectrumSettingsEvent {
  final int gap;
  UpdateTempStopGap(this.gap);
}

class UpdateTempTimeout extends ElectrumSettingsEvent {
  final int timeout;
  UpdateTempTimeout(this.timeout);
}

class UpdateTempRetry extends ElectrumSettingsEvent {
  final int retry;
  UpdateTempRetry(this.retry);
}

class UpdateTempMainnet extends ElectrumSettingsEvent {
  String mainnet;

  UpdateTempMainnet(this.mainnet);
}

class UpdateTempTestnet extends ElectrumSettingsEvent {
  String testnet;

  UpdateTempTestnet(this.testnet);
}

class UpdateTempValidateDomain extends ElectrumSettingsEvent {
  final bool validateDomain;
  UpdateTempValidateDomain(this.validateDomain);
}

class ResetTempNetwork extends ElectrumSettingsEvent {}

class SetupBlockchain extends ElectrumSettingsEvent {
  final bool? isLiquid;
  final bool? isTestnetLocal;

  SetupBlockchain({this.isLiquid, this.isTestnetLocal});
}
