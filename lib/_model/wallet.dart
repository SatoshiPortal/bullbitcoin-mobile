// ignore_for_file: constant_identifier_names
import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/bip329_label.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet.freezed.dart';
part 'wallet.g.dart';

enum BBNetwork { Testnet, Mainnet }

enum BBWalletType { newSeed, xpub, descriptors, words, coldcard }

enum ScriptType { bip84, bip49, bip44 }

@freezed
class Wallet with _$Wallet {
  const factory Wallet({
    @Default('') String id,
    @Default('') String externalPublicDescriptor,
    @Default('') String internalPublicDescriptor,
    @Default('') String mnemonicFingerprint,
    @Default('') String sourceFingerprint,
    required BBNetwork network,
    required BBWalletType type,
    required ScriptType scriptType,
    String? name,
    String? path,
    int? balance,
    @Default([]) List<Address> addresses,
    // @Default(-1) lastDepositIndex,
    Address? lastUnusedAddress,
    List<Address>? toAddresses,
    @Default([]) List<Transaction> transactions,
    List<String>? labelTags,
    List<Bip329Label>? bip329Labels,
    @Default(false) bool backupTested,
    @Default(false) bool hide,
  }) = _Wallet;
  const Wallet._();

  factory Wallet.fromJson(Map<String, dynamic> json) => _$WalletFromJson(json);
  bool hasPassphrase() {
    return mnemonicFingerprint != sourceFingerprint;
  }

  String purposePathString() {
    return scriptType == ScriptType.bip84
        ? '84h'
        : scriptType == ScriptType.bip49
            ? '49h'
            : '44h';
  }

  String networkPathString() {
    return network == BBNetwork.Mainnet ? '0h' : '1h';
  }

  String accountPathString() {
    return externalPublicDescriptor.split('[')[1].split(']')[0].split('/')[3];
  }

  String originString() {
    return '[$sourceFingerprint/$purposePathString()/$networkPathString()/$accountPathString()]';
  }

  // storage key
  String getRelatedSeedStorageString() {
    return mnemonicFingerprint;
  }

  String getWalletStorageString() {
    return id;
  }

  int totalReceived() {
    final txs = transactions.where((tx) => tx.isReceived()).toList();
    int amt = 0;
    for (final tx in txs) amt += tx.getAmount().abs();
    return amt;
  }

  int totalSent() {
    final txs = transactions.where((tx) => !tx.isReceived()).toList();
    int amt = 0;
    for (final tx in txs) amt += tx.getAmount(sentAsTotal: true).abs();
    return amt;
  }

  List<Address> addressesWithBalance() {
    return addresses.where((addr) => addr.calculateBalance() > 0).toList();
  }

  List<Address> addressesWithoutBalance({bool isUsed = false}) {
    if (!isUsed)
      return addresses.where((addr) => addr.calculateBalance() == 0).toList();
    else
      return addresses.where((addr) => addr.hasSpentAndNoBalance()).toList();
  }

  String getAddressFromTxid(String txid) {
    for (final address in addresses)
      for (final utxo in address.utxos ?? <bdk.LocalUtxo>[])
        if (utxo.outpoint.txid == txid) return address.address; // this will return change

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

  String getWalletTypeString() {
    String str = '';

    switch (type) {
      case BBWalletType.newSeed:
        str = 'Bull Bitcoin Wallet';
        if (hasPassphrase())
          str += '\n(Passphrase Protected)';
        else
          str += '\n(No Passphrase)';

      case BBWalletType.xpub:
        str = 'Imported Xpub';
      case BBWalletType.words:
        str = 'Imported Mnemonic';
        if (hasPassphrase())
          str += '\n(Passphrase Protected)';
        else
          str += '\n(No Passphrase)';
      case BBWalletType.coldcard:
        str = 'Imported Coldcard';

      case BBWalletType.descriptors:
        str = 'Imported Descriptors';
    }

    return str;
  }

  String defaultNameString() {
    String str = '';

    switch (type) {
      case BBWalletType.newSeed:
        str = 'Bull Wallet' + ':' + id.substring(0, 5);
      case BBWalletType.xpub:
        str = 'Xpub' + ':' + id.substring(0, 5);
      case BBWalletType.words:
        str = 'Imported' + ':' + id.substring(0, 5);
      case BBWalletType.coldcard:
        str = 'Coldcard' + ':' + id.substring(0, 5);
      case BBWalletType.descriptors:
        str = 'Imported Descriptor' + ':' + id.substring(0, 5);
    }

    return str;
  }

  String getWalletTypeShortString() {
    switch (type) {
      case BBWalletType.newSeed:
      case BBWalletType.words:
        return 'Spendable on-chain';
      case BBWalletType.xpub:
      // return 'Watch Only';
      case BBWalletType.coldcard:
      // return 'Watch Only';

      case BBWalletType.descriptors:
        return 'Watch Only';
    }
  }

  List<Transaction> getPendingTxs() {
    return transactions.where((tx) => tx.timestamp == 0 && !tx.oldTx).toList().reversed.toList();
  }

  List<Transaction> getConfirmedTxs() {
    final txs = transactions.where((tx) => tx.timestamp != 0 && !tx.oldTx).toList();
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

  List<Address> allFreezedAddresses() {
    final all = <Address>[];
    all.addAll(addresses);
    all.addAll(toAddresses ?? <Address>[]);
    return all.where((addr) => addr.unspendable).toList();
  }

  bool isActive() {
    if (balance != null && balance! > 0) return true;
    if (transactions.isNotEmpty) return true;

    return false;
  }

  int txSentCount() {
    return transactions.where((tx) => !tx.isReceived()).toList().length;
  }

  int txReceivedCount() {
    return transactions.where((tx) => tx.isReceived()).toList().length;
  }
}

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

String scriptTypeString(ScriptType scriptType) {
  var name = '';
  switch (scriptType) {
    case ScriptType.bip84:
      name = 'Segwit';
    case ScriptType.bip49:
      name = 'Legacy Script';
    case ScriptType.bip44:
      name = 'Legacy Pubkey';
  }
  return name;
}

extension W on ScriptType {
  String pathsString() {
    switch (this) {
      case ScriptType.bip84:
        return '84';
      case ScriptType.bip49:
        return '49';
      case ScriptType.bip44:
        return '44';
    }
  }
}

// segwit -> BIP84 -> m/84'/0'/0'/0-1/* -> wpkh
// compatible -> BIP49 -> m/49'/0'/0'/0-1/* -> sh-wpkh
// legacy -> BIP44 -> m/44'/0'/0'/0-1/* -> pkh
