class WalletEvent {}

// class LoadWallet extends WalletEvent {
//   LoadWallet(this.saveDir);

//   final String saveDir;
// }

class WalletSubscribe extends WalletEvent {
  WalletSubscribe(this.walletId);

  final String walletId;
}

class SyncWallet extends WalletEvent {
  SyncWallet({this.cancelSync = false});

  final bool cancelSync;
}

class RemoveInternalWallet extends WalletEvent {}

class KillSync extends WalletEvent {}

// class UpdateWallet extends WalletEvent {
//   UpdateWallet(
//     this.wallet, {
//     this.saveToStorage = true,
//     required this.updateTypes,
//     this.syncAfter = false,
//     this.delaySync = 500,
//   });
//   final Wallet wallet;
//   final bool saveToStorage;
//   final bool syncAfter;
//   final int delaySync;
//   final List<UpdateWalletTypes> updateTypes;
// }

// class GetBalance extends WalletEvent {}

// class GetAddresses extends WalletEvent {}

// class ListTransactions extends WalletEvent {}

// class GetFirstAddress extends WalletEvent {}

// class GetNewAddress extends WalletEvent {}

// enum UpdateWalletTypess {
//   load,
//   balance,
//   transactions,
//   swaps,
//   addresses,
//   settings,
//   utxos
// }
