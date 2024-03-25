import 'package:bb_mobile/_model/wallet.dart';

class WalletEvent {}

class LoadWallet extends WalletEvent {
  LoadWallet(this.saveDir);

  final String saveDir;
}

class SyncWallet extends WalletEvent {
  SyncWallet({this.cancelSync = false});

  final bool cancelSync;
}

class KillSync extends WalletEvent {}

class UpdateWallet extends WalletEvent {
  UpdateWallet(this.wallet, {this.saveToStorage = true, required this.updateTypes});
  final Wallet wallet;
  final bool saveToStorage;
  final List<UpdateWalletTypes> updateTypes;
}

class GetBalance extends WalletEvent {}

// class GetAddresses extends WalletEvent {}

class UpdateUtxos extends WalletEvent {}

class ListTransactions extends WalletEvent {}

class GetFirstAddress extends WalletEvent {}

class GetNewAddress extends WalletEvent {}

enum UpdateWalletTypes { load, balance, transactions, swaps, addresses, settings, utxos }
