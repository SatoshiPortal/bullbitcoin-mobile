import 'package:bb_mobile/_model/wallet.dart';

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
  WalletUpdated(this.wallet);
  final Wallet wallet;
}

class WalletsSubscribe extends HomeEvent {}
