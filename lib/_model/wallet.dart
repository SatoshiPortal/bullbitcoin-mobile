// ignore_for_file: constant_identifier_names
import 'dart:convert';

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:crypto/crypto.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet.freezed.dart';
part 'wallet.g.dart';

enum BBNetwork { Testnet, Mainnet }

enum BBWalletType { secure, xpub, descriptors, words, coldcard, instant }

enum ScriptType { bip84, bip49, bip44 }

enum BaseWalletType { Bitcoin, Liquid }

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
    Balance? fullBalance,
    Address? lastGeneratedAddress,
    @Default([]) List<Address> myAddressBook,
    List<Address>? externalAddressBook,
    @Default([]) List<UTXO> utxos,
    @Default([]) List<Transaction> transactions,
    @Default([]) List<Transaction> unsignedTxs,
    @Default([]) List<SwapTx> swaps,
    @Default(0) int revKeyIndex,
    @Default(0) int subKeyIndex,
    // List<String>? labelTags,
    // List<Bip329Label>? bip329Labels,
    @Default(false) bool backupTested,
    DateTime? lastBackupTested,
    @Default(false) bool hide,
    @Default(false) bool mainWallet,
    required BaseWalletType baseWalletType,
  }) = _Wallet;
  const Wallet._();

  factory Wallet.fromJson(Map<String, dynamic> json) => _$WalletFromJson(json);

  // Address? getLastAddress() =>
  //     baseWalletType == BaseWalletType.Bitcoin ? lastGeneratedAddress : lastGeneratedLiqAddress;

  bool isLiquid() => baseWalletType == BaseWalletType.Liquid;

  Wallet setLastAddress(Address address) {
    return copyWith(lastGeneratedAddress: address);
  }

  bool hasOngoingSwap(String id) {
    return swaps.any((swap) => swap.id == id);
  }

  SwapTx? getOngoingSwap(String id) {
    if (hasOngoingSwap(id))
      return swaps.firstWhere((element) => element.id == id);
    return null;
  }

  bool hasPassphrase() {
    return mnemonicFingerprint != sourceFingerprint;
  }

  int addressGap() {
    final List<Address> sortedAddresses = List.from(myAddressBook)
      ..sort((a, b) => (a.index ?? 0).compareTo(b.index ?? 0));

    final int lastUsedIndex = sortedAddresses
        .lastIndexWhere((address) => address.state == AddressStatus.used);
    final int lastActiveIndex = sortedAddresses
        .lastIndexWhere((address) => address.state == AddressStatus.active);

    final lastIndexForGap =
        (lastActiveIndex > lastUsedIndex) ? lastActiveIndex : lastUsedIndex;
    // If there's no address with status "used", return the count of all addresses as they're all unused
    if (lastIndexForGap == -1) {
      return sortedAddresses.length;
    }

    return sortedAddresses.length - lastIndexForGap;
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
    print(externalPublicDescriptor);
    return (externalPublicDescriptor.contains('['))
        ? externalPublicDescriptor.split('[')[1].split(']')[0].split('/')[3]
        : "0'";
  }

  String derivationPathString() {
    if (baseWalletType == BaseWalletType.Bitcoin) {
      return 'm/${purposePathString()}/${networkPathString()}/${accountPathString()}'
          .replaceAll('h', "'");
    } else {
      if (network == BBNetwork.Testnet) {
        return 'm/${purposePathString()}/${networkPathString()}/${accountPathString()}'
            .replaceAll('h', "'");
      } else {
        return 'm/${purposePathString()}/1776h/${accountPathString()}'
            .replaceAll('h', "'");
      }
    }
  }

  String originString() {
    if (sourceFingerprint == '') return 'unknown';
    return '[$sourceFingerprint/$purposePathString()/$networkPathString()/$accountPathString()]';
  }

  String getDescriptorCombined() {
    return externalPublicDescriptor.replaceAll('/0/', '/[0;1]/');
  }

  String generateBIP329Key() {
    final exDescDerivedKey = sha256
        .convert(
          utf8.encode(
            // allows passing either internal or external descriptor
            externalPublicDescriptor,
          ),
        )
        .toString();
    return exDescDerivedKey;
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

  String getAddressFromTxid(String txid) {
    // TODO: UTXO
    // Updated / Simplified (Seach specific to utxos. Is this fine?)
    for (final utxo in utxos)
      if (utxo.txid == txid) return utxo.address.address;
    for (final tx in transactions) {
      for (final addrs in tx.outAddrs)
        if (addrs.spentTxId == txid) return addrs.address;
    }
    return '';

    /*
    for (final address in myAddressBook)
      for (final utxo in address.utxos ?? <bdk.LocalUtxo>[])
        if (utxo.outpoint.txid == txid) return address.address; // this will return change
    */
  }

  Address? findAddressInWallet(String address) {
    final completeAddressBook = [
      ...externalAddressBook ?? [],
      ...myAddressBook,
    ];
    for (final existingAddress in completeAddressBook) {
      if (address == existingAddress.address) return existingAddress;
    }
    return null;
  }

  Address? getAddressFromAddresses(
    String txid, {
    bool isSend = false,
    AddressKind? kind,
  }) {
    for (final address
        in (isSend ? externalAddressBook : myAddressBook) ?? <Address>[])
      if (isSend) {
        if (address.spentTxId == txid) {
          if (kind == null) {
            return address;
          } else if (kind == address.kind) {
            return address;
          }
        }
      } else {
        // TODO: UTXO
        for (final utxo in utxos) {
          if (utxo.address.address == address.address && utxo.txid == txid) {
            if (kind == null) {
              return address;
            } else if (kind == address.kind) {
              return address;
            }
          }
        }
        /*
        for (final utxo in address.utxos ?? <bdk.LocalUtxo>[]) {
          if (utxo.outpoint.txid == txid) {
            if (kind == null) {
              return address;
            } else if (kind == address.kind) {
              return address;
            }
          }
        }
        */
        return null;
      }

    return null;
  }

  String getWalletTypeString() {
    String str = '';

    switch (type) {
      case BBWalletType.secure:
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
      case BBWalletType.instant:
        str = 'Instant Payments Wallet';
    }

    return str;
  }

  String defaultNameString() {
    String str = '';

    switch (type) {
      case BBWalletType.secure:
        str = 'Bull Wallet' + ':' + id.substring(0, 5);
      case BBWalletType.xpub:
        str = 'Xpub' + ':' + id.substring(0, 5);
      case BBWalletType.words:
        str = 'Imported' + ':' + id.substring(0, 5);
      case BBWalletType.coldcard:
        str = 'Coldcard' + ':' + id.substring(0, 5);
      case BBWalletType.descriptors:
        str = 'Imported Descriptor' + ':' + id.substring(0, 5);
      case BBWalletType.instant:
        str = 'Instant' + ':' + id.substring(0, 5);
    }

    return str;
  }

  String creationName() {
    String str = '';

    switch (type) {
      case BBWalletType.words:
      case BBWalletType.secure:
        str = 'Secure Bitcoin Wallet';
      case BBWalletType.xpub:
        str = 'Xpub' + ':' + id.substring(0, 5);
      case BBWalletType.coldcard:
        str = 'Coldcard' + ':' + id.substring(0, 5);
      case BBWalletType.descriptors:
        str = 'Imported Descriptor' + ':' + id.substring(0, 5);
      case BBWalletType.instant:
        str = 'Instant payments wallet';
    }

    return str;
  }

  String getWalletTypeStr({bool shorten = false}) {
    final isTestnet = network == BBNetwork.Testnet;
    final networkStr = isTestnet ? 'Testnet' : 'Mainnet';

    switch (type) {
      case BBWalletType.secure:
      case BBWalletType.words:
        return shorten
            ? '$networkStr on-chain'
            : 'Regular on-chain $networkStr Network';
      case BBWalletType.xpub:
      case BBWalletType.coldcard:
      case BBWalletType.descriptors:
        return 'Watch Only';
      case BBWalletType.instant:
        return shorten ? 'Liquid $networkStr' : 'Liquid $networkStr Network';
    }
  }

  List<Transaction> getPendingTxs() {
    return transactions
        .map((e) => e.copyWith(wallet: this))
        .where((tx) => tx.timestamp == 0 && !tx.oldTx)
        .toList()
        .reversed
        .toList();
  }

  List<Transaction> getConfirmedTxs() {
    final txs = transactions
        .map((e) => e.copyWith(wallet: this))
        .where((tx) => tx.timestamp != 0 && !tx.oldTx)
        .toList();
    txs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return txs;
  }

  bool watchOnly() =>
      type == BBWalletType.xpub ||
      type == BBWalletType.coldcard ||
      type == BBWalletType.descriptors;

  bdk.Network? getBdkNetwork() {
    switch (network) {
      case BBNetwork.Testnet:
        return bdk.Network.testnet;
      case BBNetwork.Mainnet:
        return bdk.Network.bitcoin;

      // case BBNetwork.LTestnet:
      // case BBNetwork.LMainnet:
      //   return null;
    }
    // return null;
  }

  bool isSameNetwork(bool isTestnet) {
    return (isTestnet && network == BBNetwork.Testnet) ||
        (!isTestnet && network == BBNetwork.Mainnet);
  }

  List<Address> allFreezedAddresses() {
    final all = <Address>[];
    all.addAll(myAddressBook);
    all.addAll(externalAddressBook ?? <Address>[]);
    return all
        .where(
          (addr) => !addr.spendable,
        )
        .toList();
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

  Transaction? getTxWithSwap(SwapTx swap) {
    final idx = transactions.indexWhere((tx) => tx.swapTx?.id == swap.id);
    if (idx == -1) return null;
    return transactions[idx];
  }

  int frozenUTXOTotal() {
    final addresses = <Address>[
      ...myAddressBook,
      ...externalAddressBook ?? <Address>[],
    ];
    final unspendable = addresses.where((_) => !_.spendable).toList();
    final totalFrozen =
        unspendable.fold<int>(0, (value, _) => value + _.balance);
    return totalFrozen;
  }

  int balanceWithoutFrozenUTXOs() =>
      (balance ?? 0) == 0 ? 0 : balance! - frozenUTXOTotal();

  List<SwapTx> swapsToProcess() =>
      swaps.where((swap) => swap.proceesTx() && !swap.failed()).toList();
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
  const Balance._();

  factory Balance.fromJson(Map<String, dynamic> json) =>
      _$BalanceFromJson(json);
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

List<String> backupInstructions(bool hasPassphrase) {
  return [
    if (hasPassphrase) ...[
      'Your backup is protected by passphrase.',
      'Without a backup, if you lose or break your phone, or if you uninstall the Bull Bitcoin app, your bitcoins will be lost forever.',
      'Anybody with access to both your 12 word backup and your passphrase can steal your bitcoins. Hide them separately.',
      'If you lose your 12 word backup or your passphrase, you will not be able to recover access to the Bitcoin Wallet. Both the 12 words and the passphrase are required.',
      'Do not make digital copies of your backup and passprhase. Write them down separately on a piece of paper, or engraved in metal.',
      // (passphrase)
      // Your backup is protected by passphrase.
      // Without a backup, if you lose or break your phone, or if you uninstall the Bull Bitcoin app, your bitcoins will be lost forever.
      // Anybody with access to both your 12 word backup and your passphrase can steal your bitcoins. Hide them separately.
      // If you lose your 12 word backup or your passphrase, you will not be able to recover access to the Bitcoin Wallet. Both the 12 words and the passphrase are required.
      // Do not make digital copies of your backup and passprhase. Write them down separately on a piece of paper, or engraved in metal.
    ] else ...[
      'If you lose your 12 word backup, you will not be able to recover access to the Bitcoin Wallet.',
      'Without a backup, if you lose or break your phone, or if you uninstall the Bull Bitcoin app, your bitcoins will be lost forever.',
      'Anybody with access to your 12 word backup can steal your bitcoins. Hide it well.',
      'Do not make digital copies of your backup. Write it down on a piece of paper, or engraved in metal.',
      'Your backup is not protected by passphrase. Add a passphrase to your backup later by creating a new wallet.',
      // (No passphrase)
      // If you lose your 12 word backup, you will not be able to recover access to the Bitcoin Wallet.
      // Without a backup, if you lose or break your phone, or if you uninstall the Bull Bitcoin app, your bitcoins will be lost forever.
      // Anybody with access to your 12 word backup can steal your bitcoins. Hide it well.
      // Do not make digital copies of your backup. Write it down on a piece of paper, or engraved in metal.
      // Your backup is not protected by passphrase. Add a passphrase to your backup later by creating a new wallet.
    ],
  ];
}

// segwit -> BIP84 -> m/84'/0'/0'/0-1/* -> wpkh
// compatible -> BIP49 -> m/49'/0'/0'/0-1/* -> sh-wpkh
// legacy -> BIP44 -> m/44'/0'/0'/0-1/* -> pkh

extension type LiqWallet(Wallet wallet) {}
