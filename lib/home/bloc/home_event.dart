import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_repository/wallet_service.dart';

class HomeEvent {}

class LoadWalletsFromStorage extends HomeEvent {}

class ClearWallets extends HomeEvent {}

class UpdateErrDeepLink extends HomeEvent {
  UpdateErrDeepLink(this.err);
  final String err;
}

class UpdatedNotifier extends HomeEvent {
  bool fromStart;

  UpdatedNotifier({this.fromStart = false});
}

class LoadWalletsForNetwork extends HomeEvent {
  LoadWalletsForNetwork(this.network);
  final BBNetwork network;
}

class WalletUpdated extends HomeEvent {
  WalletUpdated(this.walletData);
  final WalletServiceData walletData;
}

class WalletServicesUpdated extends HomeEvent {
  WalletServicesUpdated(this.walletServices);
  final List<WalletService> walletServices;
}

class WalletsSubscribe extends HomeEvent {}
