import 'package:bb_mobile/_model/network.dart';

abstract class NetworkEvent {}

class InitNetworks extends NetworkEvent {}

class LoadNetworks extends NetworkEvent {}

class ToggleTestnet extends NetworkEvent {}

class UpdateStopGapAndSave extends NetworkEvent {
  final int gap;
  UpdateStopGapAndSave(this.gap);
}

class NetworkConfigsSave extends NetworkEvent {
  final bool isLiq;
  NetworkConfigsSave({required this.isLiq});
}

class NetworkTypeChanged extends NetworkEvent {
  final ElectrumTypes type;
  NetworkTypeChanged(this.type);
}

class LiquidNetworkTypeChanged extends NetworkEvent {
  final LiquidElectrumTypes type;
  LiquidNetworkTypeChanged(this.type);
}

// // Add other events for updating network configuration...
// class UpdateMainnet extends NetworkEvent {
//   final String mainnet;
//   UpdateMainnet(this.mainnet);
// }

// class UpdateTestnet extends NetworkEvent {
//   final String testnet;
//   UpdateTestnet(this.testnet);
// }

// ... add other events as needed ...

class CloseNetworkError extends NetworkEvent {}

class RetryNetwork extends NetworkEvent {}

class UpdateTempLiquidMainnet extends NetworkEvent {
  final String mainnet;
  UpdateTempLiquidMainnet(this.mainnet);
}

class UpdateTempLiquidTestnet extends NetworkEvent {
  final String testnet;
  UpdateTempLiquidTestnet(this.testnet);
}

class UpdateTempStopGap extends NetworkEvent {
  final int gap;
  UpdateTempStopGap(this.gap);
}

class UpdateTempTimeout extends NetworkEvent {
  final int timeout;
  UpdateTempTimeout(this.timeout);
}

class UpdateTempRetry extends NetworkEvent {
  final int retry;
  UpdateTempRetry(this.retry);
}

class UpdateTempMainnet extends NetworkEvent {
  String mainnet;

  UpdateTempMainnet(this.mainnet);
}

class UpdateTempTestnet extends NetworkEvent {
  String testnet;

  UpdateTempTestnet(this.testnet);
}

class UpdateTempValidateDomain extends NetworkEvent {
  final bool validateDomain;
  UpdateTempValidateDomain(this.validateDomain);
}

class ResetTempNetwork extends NetworkEvent {}

class SetupBlockchain extends NetworkEvent {
  final bool? isLiquid;
  final bool? isTestnetLocal;

  SetupBlockchain({this.isLiquid, this.isTestnetLocal});
}

// class NetworkLoadError extends NetworkEvent {
//   final String url;
//   NetworkLoadError(this.url);
// }
