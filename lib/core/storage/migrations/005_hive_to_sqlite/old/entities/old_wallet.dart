// ignore_for_file: constant_identifier_names
import 'dart:convert';

import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_address.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_swap.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_transaction.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:crypto/crypto.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'old_wallet.freezed.dart';
part 'old_wallet.g.dart';

enum OldBBNetwork { Testnet, Mainnet }

enum OldBBWalletType { main, xpub, descriptors, words, coldcard }

enum OldScriptType { bip84, bip49, bip44 }

enum OldBaseWalletType { Bitcoin, Liquid }

extension BaseWalletTypeExtension on OldBaseWalletType {
  String get getImage {
    switch (this) {
      case OldBaseWalletType.Bitcoin:
        return Assets.misc.iconBtc.path;
      case OldBaseWalletType.Liquid:
        return Assets.misc.iconLbtc.path;
    }
  }
}

@freezed
abstract class OldWallet with _$OldWallet {
  const factory OldWallet({
    @Default('') String id,
    @Default('') String externalPublicDescriptor,
    @Default('') String internalPublicDescriptor,
    // public
    @Default('') String mnemonicFingerprint,
    @Default('') String sourceFingerprint,
    required OldBBNetwork network,
    required OldBBWalletType type,
    required OldScriptType scriptType,
    String? name,
    String? path,
    int? balance,
    Balance? fullBalance,
    @Default(false) bool backupTested,
    DateTime? lastBackupTested,
    @Default(false) bool hide,
    @Default(false) bool mainWallet,
    required OldBaseWalletType baseWalletType,
    // -------------------
    OldAddress? lastGeneratedAddress,
    @Default([]) List<OldAddress> myAddressBook, // address we receive into
    List<OldAddress>? externalAddressBook, // address that we send to
    @Default([]) List<dynamic> utxos,
    @Default([]) List<OldTransaction> transactions,
    @Default([]) List<OldTransaction> unsignedTxs, // related to hardware
    @Default([]) List<OldSwapTx> swaps,
    @Default(0) int revKeyIndex,
    @Default(0) int subKeyIndex,
    // List<String>? labelTags,
    // List<Bip329Label>? bip329Labels,
  }) = _OldWallet;
  const OldWallet._();

  factory OldWallet.fromJson(Map<String, dynamic> json) =>
      _$OldWalletFromJson(json);

  // OldAddress? getLastAddress() =>
  //     baseWalletType == OldBaseWalletType.Bitcoin ? lastGeneratedAddress : lastGeneratedLiqAddress;

  bool isTestnet() => network == OldBBNetwork.Testnet;
  bool isMainnet() => network == OldBBNetwork.Mainnet;

  bool isMain() => type == OldBBWalletType.main;
  bool isLiquid() => baseWalletType == OldBaseWalletType.Liquid;
  bool isBitcoin() => baseWalletType == OldBaseWalletType.Bitcoin;

  OldWallet setLastAddress(OldAddress address) {
    return copyWith(lastGeneratedAddress: address);
  }

  OldAddress? getAddressFromWallet(String address) {
    for (final addr in myAddressBook) {
      if (addr.address == address) return addr;
    }
    return null;
  }

  bool hasOngoingSwap(String id) {
    return swaps.any((swap) => swap.id == id);
  }

  OldSwapTx? getOngoingSwap(String id) {
    if (hasOngoingSwap(id)) {
      return swaps.firstWhere((element) => element.id == id);
    }
    return null;
  }

  bool hasPassphrase() {
    return mnemonicFingerprint != sourceFingerprint;
  }

  int addressGap() {
    final List<OldAddress> sortedAddresses = List.from(myAddressBook)
      ..sort((a, b) => (a.index ?? 0).compareTo(b.index ?? 0));

    final int lastUsedIndex = sortedAddresses.lastIndexWhere(
      (address) => address.state == OldAddressStatus.used,
    );
    final int lastActiveIndex = sortedAddresses.lastIndexWhere(
      (address) => address.state == OldAddressStatus.active,
    );

    final lastIndexForGap =
        (lastActiveIndex > lastUsedIndex) ? lastActiveIndex : lastUsedIndex;
    // If there's no address with status "used", return the count of all addresses as they're all unused
    if (lastIndexForGap == -1) {
      return sortedAddresses.length;
    }

    return sortedAddresses.length - lastIndexForGap;
  }

  String purposePathString() {
    return scriptType == OldScriptType.bip84
        ? '84h'
        : scriptType == OldScriptType.bip49
        ? '49h'
        : '44h';
  }

  String networkPathString() {
    return network == OldBBNetwork.Mainnet ? '0h' : '1h';
  }

  String accountPathString() {
    return (externalPublicDescriptor.contains('['))
        ? externalPublicDescriptor.split('[')[1].split(']')[0].split('/')[3]
        : "0'";
  }

  String derivationPathString() {
    if (baseWalletType == OldBaseWalletType.Bitcoin) {
      return 'm/${purposePathString()}/${networkPathString()}/${accountPathString()}'
          .replaceAll('h', "'");
    } else {
      if (network == OldBBNetwork.Testnet) {
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
    final exDescDerivedKey =
        sha256
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
    // TODO: Sai: Uncomment this (or) add :testnet while saving testnet seed (later)
    // final istestnet = network == OldBBNetwork.Testnet ? ':testnet' : '';
    // return mnemonicFingerprint + istestnet;
    return mnemonicFingerprint;
  }

  String getWalletStorageString() {
    return id;
  }

  int totalReceived() {
    final txs =
        transactions.where((tx) => tx.getNetAmountToPayee() > 0).toList();
    int amt = 0;
    for (final tx in txs) {
      amt += tx.getNetAmountToPayee().abs();
    }
    return amt;
  }

  int totalSent() {
    final txs =
        transactions.where((tx) => tx.getNetAmountIncludingFees() < 0).toList();
    int amt = 0;
    for (final tx in txs) {
      amt += tx.getNetAmountIncludingFees().abs();
    }
    return amt;
  }

  String getAddressFromTxid(String txid) {
    for (final utxo in utxos) {
      if (utxo is OldUTXO && utxo.txid == txid) return utxo.address.address;
    }
    for (final tx in transactions) {
      for (final addrs in tx.outAddrs) {
        if (addrs.spentTxId == txid) return addrs.address;
      }
    }
    return '';
  }

  OldAddress? findAddressInWallet(String address) {
    final completeAddressBook = [
      ...externalAddressBook ?? [],
      ...myAddressBook,
    ];
    for (final existingAddress in completeAddressBook) {
      if (address == existingAddress.address) return existingAddress;
    }
    return null;
  }

  OldAddress? getAddressFromAddresses(
    String txid, {
    bool isSend = false,
    OldAddressKind? kind,
  }) {
    for (final address
        in (isSend ? externalAddressBook : myAddressBook) ?? <OldAddress>[]) {
      if (isSend) {
        if (address.spentTxId == txid) {
          if (kind == null) {
            return address;
          } else if (kind == address.kind) {
            return address;
          }
        }
      } else {
        // TODO: OldUTXO
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
        // TODO: Sai: Removed this unwanted return, to deposit address is properly checked by looping through all address.
        // With this return, only first address is checked for.
        // Just look for any negative consequences of this.
        // return null;
      }
    }

    return null;
  }

  String getWalletTypeString() {
    String str = '';

    switch (type) {
      case OldBBWalletType.main:
        if (baseWalletType == OldBaseWalletType.Bitcoin) {
          str = 'Bull Bitcoin OldWallet';
        } else {
          str = 'Instant Payments OldWallet';
        }
        if (hasPassphrase()) {
          str += '\n(Passphrase Protected)';
        } else {
          str += '\n(No Passphrase)';
        }

      case OldBBWalletType.xpub:
        str = 'Imported Xpub';
      case OldBBWalletType.words:
        str = 'Imported Mnemonic';
        if (hasPassphrase()) {
          str += '\n(Passphrase Protected)';
        } else {
          str += '\n(No Passphrase)';
        }
      case OldBBWalletType.coldcard:
        str = 'Imported Coldcard';

      case OldBBWalletType.descriptors:
        str = 'Imported Descriptors';
    }

    return str;
  }

  String defaultNameString() {
    String str = '';

    switch (type) {
      case OldBBWalletType.main:
        if (baseWalletType == OldBaseWalletType.Bitcoin) {
          str = 'Secure:${id.substring(0, 5)}';
        } else {
          str = 'Instant:${id.substring(0, 5)}';
        }
      case OldBBWalletType.xpub:
        str = 'Xpub:${id.substring(0, 5)}';
      case OldBBWalletType.words:
        str = 'Imported:${id.substring(0, 5)}';
      case OldBBWalletType.coldcard:
        str = 'Coldcard:${id.substring(0, 5)}';
      case OldBBWalletType.descriptors:
        str = 'Imported Descriptor:${id.substring(0, 5)}';
    }

    return str;
  }

  String creationName() {
    String str = '';

    switch (type) {
      case OldBBWalletType.words:
      case OldBBWalletType.main:
        if (baseWalletType == OldBaseWalletType.Bitcoin) {
          str = 'Secure Bitcoin Wallet';
        } else {
          str = 'Instant Payments Wallet';
        }
      case OldBBWalletType.xpub:
        str = 'Xpub:${id.substring(0, 5)}';
      case OldBBWalletType.coldcard:
        str = 'Coldcard:${id.substring(0, 5)}';
      case OldBBWalletType.descriptors:
        str = 'Imported Descriptor:${id.substring(0, 5)}';
    }

    return str;
  }

  String getWalletTypeStr({bool shorten = false}) {
    final isTestnet = network == OldBBNetwork.Testnet;
    final networkStr = isTestnet ? 'Testnet ' : '';

    switch (type) {
      case OldBBWalletType.main:
        if (baseWalletType == OldBaseWalletType.Bitcoin) {
          return 'Bitcoin ${networkStr}Network';
        } else {
          return 'Liquid ${networkStr}Network';
        }

      case OldBBWalletType.words:
        return 'Bitcoin ${networkStr}Network';
      // return shorten
      //     ? 'Bitcoin $networkStr on-chain'
      //     : 'Regular on-chain $networkStr Network';
      case OldBBWalletType.xpub:
      case OldBBWalletType.coldcard:
      case OldBBWalletType.descriptors:
        return 'Watch Only';
      // return shorten ? 'Liquid $networkStr' : 'Liquid $networkStr Network';
    }
  }

  List<OldTransaction> getPendingTxs() {
    return transactions
        // .map(
        //   (e) => e,//.copyWith(wallet: this),
        // )
        .where(
          (tx) =>
              tx.timestamp == 0 &&
              ((baseWalletType == OldBaseWalletType.Bitcoin && !tx.isLiquid) ||
                  (baseWalletType == OldBaseWalletType.Liquid && tx.isLiquid)),
        )
        .toList()
        .reversed
        .toList();
  }

  List<OldTransaction> getConfirmedTxs() {
    final txs =
        transactions
            // .map((e) => e.copyWith(wallet: this))
            .where(
              (tx) =>
                  tx.timestamp != 0 &&
                  ((baseWalletType == OldBaseWalletType.Bitcoin &&
                          !tx.isLiquid) ||
                      (baseWalletType == OldBaseWalletType.Liquid &&
                          tx.isLiquid)),
            )
            .toList();
    txs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return txs;
  }

  OldTransaction? getTxWithId(String id) {
    final txs = transactions.where((tx) => tx.txid == id).toList();
    return txs.isNotEmpty ? txs[0] : null;
  }

  bool watchOnly() =>
      type == OldBBWalletType.xpub ||
      type == OldBBWalletType.coldcard ||
      type == OldBBWalletType.descriptors;

  bdk.Network? getBdkNetwork() {
    switch (network) {
      case OldBBNetwork.Testnet:
        return bdk.Network.testnet;
      case OldBBNetwork.Mainnet:
        return bdk.Network.bitcoin;

      // case OldBBNetwork.LTestnet:
      // case OldBBNetwork.LMainnet:
      //   return null;
    }
    // return null;
  }

  bool isInstant() =>
      type == OldBBWalletType.main &&
      baseWalletType == OldBaseWalletType.Liquid;

  bool isSecure() =>
      type == OldBBWalletType.main &&
      baseWalletType == OldBaseWalletType.Bitcoin;

  bool isSameNetwork(bool isTestnet) {
    return (isTestnet && network == OldBBNetwork.Testnet) ||
        (!isTestnet && network == OldBBNetwork.Mainnet);
  }

  List<OldAddress> allFreezedAddresses() {
    final all = <OldAddress>[];
    all.addAll(myAddressBook);
    all.addAll(externalAddressBook ?? <OldAddress>[]);
    return all.where((addr) => !addr.spendable).toList();
  }

  List<OldUTXO> allFreezedUtxos() {
    return utxos
        .where((utxo) => utxo is OldUTXO && utxo.spendable == false)
        .cast<OldUTXO>()
        .toList();
  }

  List<OldUTXO> spendableUtxos() {
    return utxos
        .where((utxo) => utxo is OldUTXO && utxo.spendable == true)
        .cast<OldUTXO>()
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

  OldTransaction? getTxWithSwap(OldSwapTx swap) {
    final idx = transactions.indexWhere((tx) => tx.swapTx?.id == swap.id);
    if (idx == -1) return null;
    return transactions[idx];
  }

  int frozenUTXOTotal() {
    final addresses = <OldAddress>[...myAddressBook];
    final unspendable =
        addresses
            .where(
              (address) =>
                  !address.spendable &&
                  (address.state == OldAddressStatus.active),
            )
            .toList();
    final totalFrozen = unspendable.fold<int>(
      0,
      (value, address) => value + address.balance,
    );
    return totalFrozen;
  }

  int balanceWithoutFrozenUTXOs() =>
      (balance ?? 0) == 0 ? 0 : balance! - frozenUTXOTotal();

  List<OldSwapTx> swapsToProcess() {
    return swaps.where((swap) => swap.proceesTx() && !swap.failed()).toList();
  }
}

@freezed
abstract class Balance with _$Balance {
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

String scriptTypeString(OldScriptType scriptType) {
  var name = '';
  switch (scriptType) {
    case OldScriptType.bip84:
      name = 'Segwit';
    case OldScriptType.bip49:
      name = 'Legacy Script';
    case OldScriptType.bip44:
      name = 'Legacy Pubkey';
  }
  return name;
}

extension W on OldScriptType {
  String pathsString() {
    switch (this) {
      case OldScriptType.bip84:
        return '84';
      case OldScriptType.bip49:
        return '49';
      case OldScriptType.bip44:
        return '44';
    }
  }

  String getScriptString() {
    var name = '';
    switch (this) {
      case OldScriptType.bip84:
        name = 'Segwit';
      case OldScriptType.bip49:
        name = 'Legacy Script';
      case OldScriptType.bip44:
        name = 'Legacy Pubkey';
    }
    return name;
  }
}

List<String> backupInstructions(bool hasPassphrase) {
  return [
    if (hasPassphrase) ...[
      'Your backup is protected by passphrase.',
      'Without a backup, if you lose or break your phone, or if you uninstall the Bull Bitcoin app, your bitcoins will be lost forever.',
      'Anybody with access to both your 12 word backup and your passphrase can steal your bitcoins. Hide them separately.',
      'If you lose your 12 word backup or your passphrase, you will not be able to recover access to the Bitcoin OldWallet. Both the 12 words and the passphrase are required.',
      'Do not make digital copies of your backup and passprhase. Write them down separately on a piece of paper, or engraved in metal.',
      // (passphrase)
      // Your backup is protected by passphrase.
      // Without a backup, if you lose or break your phone, or if you uninstall the Bull Bitcoin app, your bitcoins will be lost forever.
      // Anybody with access to both your 12 word backup and your passphrase can steal your bitcoins. Hide them separately.
      // If you lose your 12 word backup or your passphrase, you will not be able to recover access to the Bitcoin OldWallet. Both the 12 words and the passphrase are required.
      // Do not make digital copies of your backup and passprhase. Write them down separately on a piece of paper, or engraved in metal.
    ] else ...[
      'If you lose your 12 word backup, you will not be able to recover access to the Bitcoin OldWallet.',
      'Without a backup, if you lose or break your phone, or if you uninstall the Bull Bitcoin app, your bitcoins will be lost forever.',
      'Anybody with access to your 12 word backup can steal your bitcoins. Hide it well.',
      'Do not make digital copies of your backup. Write it down on a piece of paper, or engraved in metal.',
      'Your backup is not protected by passphrase. Add a passphrase to your backup later by creating a new wallet.',
      // (No passphrase)
      // If you lose your 12 word backup, you will not be able to recover access to the Bitcoin OldWallet.
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

extension type LiqWallet(OldWallet wallet) {}
