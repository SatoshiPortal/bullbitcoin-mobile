// ignore_for_file: constant_identifier_names

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet2.freezed.dart';
part 'wallet2.g.dart';

enum BBNetwork { Testnet, Mainnet }

enum BBWalletType { newSeed, xpub, descriptors, words, coldcard }

enum WalletPurpose { bip84, bip49, bip44 }

// seed -> w1() w2() w3()

@freezed
class Wallet with _$Wallet {
  const factory Wallet({
    required String walletHashId, // sha1(externalPublicDescriptor).toString().substring(12, 20)
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
    // @Default('') String mnemonic,
    // String? password,
    String? xpub,
    required String mnemonicFingerprint, // fingerprint of the 12 words / seed
    required String
        sourceFingerprint, // the fingerprint of the source which could be only the seed or seed+passphrase
    // if sourceFingerprint is different from mnemonicFingerprint; the wallet has a passphrase
    required BBNetwork network, //
    required BBWalletType type,
    required WalletPurpose purpose, // bip49,44,84
    // String? address,
    String? name,
    String? path,
    int? balance,
    List<Address>? addresses,
    List<Address>? toAddresses,
    List<Transaction>? transactions,
    @Default(false) bool backupTested,
    @Default(false) bool hide,
  }) = _Wallet;
  const Wallet._();

  factory Wallet.fromJson(Map<String, dynamic> json) => _$WalletFromJson(json);

  // storage key
  String getRelatedSeedStorageString() {
    return mnemonicFingerprint;
  }

  String getWalletStorageString() {
    return walletHashId;
  }

  int totalReceived() {
    final txs = transactions?.where((tx) => tx.isReceived()).toList() ?? [];
    int amt = 0;
    for (final tx in txs) amt += tx.getAmount().abs();
    return amt;
  }

  int totalSent() {
    final txs = transactions?.where((tx) => !tx.isReceived()).toList() ?? [];
    int amt = 0;
    for (final tx in txs) amt += tx.getAmount(sentAsTotal: true).abs();
    return amt;
  }

  List<Address> addressesWithBalance() {
    return addresses?.where((addr) => addr.calculateBalance() > 0).toList() ?? [];
  }

  List<Address> addressesWithoutBalance({bool isUsed = false}) {
    if (!isUsed)
      return addresses?.where((addr) => addr.calculateBalance() == 0).toList() ?? [];
    else
      return addresses?.where((addr) => addr.hasSpentAndNoBalance()).toList() ?? [];
  }

  String getAddressFromTxid(String txid) {
    for (final address in addresses ?? <Address>[])
      for (final utxo in address.utxos ?? <bdk.LocalUtxo>[])
        if (utxo.outpoint.txid == txid) return address.address;

    return '';
  }

  Address? getAddressFromAddresses(String txid, {bool isSend = false}) {
    for (final address in (isSend ? toAddresses : addresses) ?? <Address>[])
      if (isSend) {
        if (address.sentTxId == txid) {
          return address;
        }
      } else {
        for (final utxo in address.utxos ?? <bdk.LocalUtxo>[]) {
          if (utxo.outpoint.txid == txid) {
            return address;
          }
        }
      }

    return null;
  }

  String getWalletTypeStr() {
    String str = '';

    final hasPassphrase = mnemonicFingerprint != sourceFingerprint;
    switch (type) {
      case BBWalletType.newSeed:
        str = 'Bull Bitcoin Wallet';
        if (hasPassphrase)
          str += '\n(Passphase Protected)';
        else
          str += '\n(No passphase)';

      case BBWalletType.xpub:
        str = 'Imported Xpub';
      case BBWalletType.words:
        str = 'Recovered Wallet';
        if (hasPassphrase)
          str += '\n(Passphase Protected)';
        else
          str += '\n(No passphase)';
      case BBWalletType.coldcard:
        str = 'Imported Coldcard';

      case BBWalletType.descriptors:
        str = 'Imported Descriptors';
    }

    // final name = walletNameStr(walletType);
    // str += '\n$name';

    return str;
  }

  String getWalletTypeShortStr() {
    switch (type) {
      case BBWalletType.newSeed:
      case BBWalletType.words:
        return 'Spendable';
      case BBWalletType.xpub:
      case BBWalletType.coldcard:
      // we could allow import of spendable private descriptors too; for example from Muun
      // for now we assume descriptor imports are watch-only public only
      case BBWalletType.descriptors:
        return 'Watch Only';
    }
  }

  List<Transaction> getPendingTxs() {
    return (transactions?.where((tx) => tx.timestamp == 0 && !tx.oldTx).toList().reversed ?? [])
        .toList();
  }

  List<Transaction> getConfirmedTxs() {
    final txs = transactions?.where((tx) => tx.timestamp != 0 && !tx.oldTx).toList() ?? [];
    txs.sort((a, b) => b.timestamp?.compareTo(a.timestamp ?? 0) ?? 0);
    return txs;
  }

  bool watchOnly() =>
      type == BBWalletType.xpub ||
      type == BBWalletType.coldcard ||
      type == BBWalletType.descriptors;

  bdk.Network getBdkNetwork() {
    switch (network) {
      case BBNetwork.Testnet:
        return bdk.Network.Testnet;
      case BBNetwork.Mainnet:
        return bdk.Network.Bitcoin;
    }
  }

  // List<Address> allAddresses() {
  //   final all = <Address>[];
  //   all.addAll(addresses ?? <Address>[]);
  //   all.addAll(toAddresses ?? <Address>[]);
  //   return all;
  // }

  List<Address> allFreezedAddresses() {
    final all = <Address>[];
    all.addAll(addresses ?? <Address>[]);
    all.addAll(toAddresses ?? <Address>[]);
    return all.where((addr) => addr.unspendable).toList();
  }

  bool isActive() {
    if (balance != null && balance! > 0) return true;
    if (transactions != null && transactions!.isNotEmpty) return true;

    return false;
  }
}

// @freezed
// class WalletDetails with _$WalletDetails {
//   const factory WalletDetails({
//     // required String name,
//     required String firstAddress,
//     required String fingerPrint,
//     String? expandedPubKey,
//     required String derivationPath,
//     required WalletType type,
//   }) = _WalletDetails;

//   const WalletDetails._();

//   String cleanFingerprint() {
//     if (fingerPrint.startsWith('tn')) return fingerPrint.replaceFirst('tn::', '');
//     return fingerPrint;
//   }
// }

@freezed
class Balance with _$Balance {
  const factory Balance({
    required int immature,
    required int trustedPending,
    required int untrustedPending,
    required int confirmed,
    required int spendable,
    required int total,
  }) = _Balance;
}

String walletNameStr(WalletPurpose type) {
  var name = '';
  switch (type) {
    case WalletPurpose.bip84:
      name = 'Segwit';
    case WalletPurpose.bip49:
      name = 'Legacy Script';
    case WalletPurpose.bip44:
      name = 'Legacy Pubkey';
  }
  return name;
}

extension W on WalletPurpose {
  String walletNumber() {
    switch (this) {
      case WalletPurpose.bip84:
        return '84';
      case WalletPurpose.bip49:
        return '49';
      case WalletPurpose.bip44:
        return '44';
    }
  }
}




// segwit -> BIP84 -> m/84'/0'/0'/0-1/* -> wpkh
// compatible -> BIP49 -> m/49'/0'/0'/0-1/* -> sh-wpkh
// legacy -> BIP44 -> m/44'/0'/0'/0-1/* -> pkh
