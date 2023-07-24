// ignore_for_file: constant_identifier_names
import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/cold_card.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/wallet/utils.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet.freezed.dart';
part 'wallet.g.dart';

enum BBNetwork { Testnet, Mainnet }

enum BBWalletType { newSeed, xpub, descriptors, words, coldcard }

enum WalletPurpose { bip84, bip49, bip44 }

@freezed
class Wallet with _$Wallet {
  const factory Wallet({
    @Default('') String externalPublicDescriptor,
    @Default('') String internalPublicDescriptor,
    @Default('') String mnemonic,
    String? password,
    String? xpub,
    @Default('') String fingerprint,
    required BBNetwork network,
    required BBWalletType type,
    required WalletPurpose purpose,
    // String? address,
    String? name,
    String? path,
    int? balance,
    List<Address>? addresses,
    List<Address>? toAddresses,
    List<Transaction>? transactions,
    @Default(false) bool backupTested,
  }) = _Wallet;
  const Wallet._();

  factory Wallet.fromJson(Map<String, dynamic> json) => _$WalletFromJson(json);

  static (List<Wallet>?, Err?) fromMnemonicAll({
    required String mne,
    required String? password,
    required BBWalletType bbWalletType,
    required bool isTestNet,
    required String fngr,
    String? path,
  }) {
    try {
      final wallets = <Wallet>[];
      final errs = <String>[];

      final (wallet84, err1) = fromMnemonic(
        mne: mne,
        password: password,
        path: path,
        walletPurpose: WalletPurpose.bip84,
        bbWalletType: bbWalletType,
        isTestNet: isTestNet,
        fngr: fngr,
        backupTested: true,
      );
      if (err1 != null) errs.add(err1.message);
      wallets.add(wallet84!);

      final (wallet49, err2) = fromMnemonic(
        mne: mne,
        password: password,
        path: path,
        walletPurpose: WalletPurpose.bip49,
        bbWalletType: bbWalletType,
        isTestNet: isTestNet,
        fngr: fngr,
        backupTested: true,
      );
      if (err2 != null) errs.add(err2.message);
      wallets.add(wallet49!);

      final (wallet44, err3) = fromMnemonic(
        mne: mne,
        password: password,
        path: path,
        walletPurpose: WalletPurpose.bip44,
        bbWalletType: bbWalletType,
        isTestNet: isTestNet,
        fngr: fngr,
        backupTested: true,
      );
      if (err3 != null) errs.add(err3.message);
      wallets.add(wallet44!);

      if (wallets.isEmpty) throw 'Unable to create a wallet:\n ${errs.join(', ')}';

      return (wallets, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  static (List<Wallet>?, Err?) fromColdCardAll({
    required ColdCard coldCard,
    required bool isTestNet,
  }) {
    try {
      final wallets = <Wallet>[];
      final errs = <String>[];

      final (wallet84, err1) = fromColdCard(
        coldCard: coldCard,
        walletPurpose: WalletPurpose.bip84,
        isTestNet: isTestNet,
      );
      if (err1 != null) errs.add(err1.message);
      wallets.add(wallet84!);

      final (wallet49, err2) = fromColdCard(
        coldCard: coldCard,
        walletPurpose: WalletPurpose.bip49,
        isTestNet: isTestNet,
      );
      if (err2 != null) errs.add(err2.message);
      wallets.add(wallet49!);

      final (wallet44, err3) = fromColdCard(
        coldCard: coldCard,
        walletPurpose: WalletPurpose.bip44,
        isTestNet: isTestNet,
      );
      if (err3 != null) errs.add(err3.message);
      wallets.add(wallet44!);

      if (wallets.isEmpty) throw 'Unable to create a wallet:\n ${errs.join(', ')}';

      return (wallets, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  static (List<Wallet>?, Err?) fromXpubWithPathAll({
    required BBWalletType bbWalletType,
    required bool isTestNet,
    required String xpub,
    required String fngr,
    required String path,
  }) {
    try {
      final wallets = <Wallet>[];
      final errs = <String>[];

      final (wallet84, err) = Wallet.fromXPubDescr(
        xpub: xpub,
        walletPurpose: WalletPurpose.bip84,
        isTestNet: isTestNet,
        path: path,
        fngr: fngr,
        bbWalletType: bbWalletType,
      );

      if (err != null) errs.add(err.message);
      wallets.add(wallet84!);

      final (wallet49, err2) = Wallet.fromXPubDescr(
        xpub: xpub,
        walletPurpose: WalletPurpose.bip49,
        path: path,
        isTestNet: isTestNet,
        bbWalletType: bbWalletType,
        fngr: fngr,
      );

      if (err2 != null) errs.add(err2.message);
      wallets.add(wallet49!);

      final (wallet44, err3) = Wallet.fromXPubDescr(
        xpub: xpub,
        walletPurpose: WalletPurpose.bip44,
        path: path,
        isTestNet: isTestNet,
        bbWalletType: bbWalletType,
        fngr: fngr,
      );

      if (err3 != null) errs.add(err3.message);
      wallets.add(wallet44!);

      if (wallets.isEmpty) throw 'Unable to create a wallet:\n ${errs.join(', ')}';
      return (wallets, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  static (List<Wallet>?, Err?) fromXpubNoPathAll({
    required BBWalletType bbWalletType,
    required bool isTestNet,
    required String xpub,
    required String fngr,
  }) {
    try {
      final wallets = <Wallet>[];
      final errs = <String>[];

      final (wallet84, err) = Wallet.fromXPubDescr(
        fngr: fngr,
        walletPurpose: WalletPurpose.bip84,
        isTestNet: isTestNet,
        bbWalletType: bbWalletType,
        changeDescriptor: buildDescriptorVanilla(
          xpub: xpub,
          walletPurpose: WalletPurpose.bip84,
          isChange: true,
        ),
        descriptor: buildDescriptorVanilla(
          xpub: xpub,
          walletPurpose: WalletPurpose.bip84,
          isChange: false,
        ),
      );

      if (err != null) errs.add(err.message);
      wallets.add(wallet84!);

      final (wallet49, err2) = Wallet.fromXPubDescr(
        fngr: fngr,
        walletPurpose: WalletPurpose.bip49,
        isTestNet: isTestNet,
        bbWalletType: bbWalletType,
        changeDescriptor: buildDescriptorVanilla(
          xpub: xpub,
          walletPurpose: WalletPurpose.bip49,
          isChange: true,
        ),
        descriptor: buildDescriptorVanilla(
          xpub: xpub,
          walletPurpose: WalletPurpose.bip49,
          isChange: false,
        ),
      );

      if (err2 != null) errs.add(err2.message);
      wallets.add(wallet49!);

      final (wallet44, err3) = Wallet.fromXPubDescr(
        fngr: fngr,
        walletPurpose: WalletPurpose.bip44,
        isTestNet: isTestNet,
        bbWalletType: bbWalletType,
        changeDescriptor: buildDescriptorVanilla(
          xpub: xpub,
          walletPurpose: WalletPurpose.bip44,
          isChange: true,
        ),
        descriptor: buildDescriptorVanilla(
          xpub: xpub,
          walletPurpose: WalletPurpose.bip44,
          isChange: false,
        ),
      );

      if (err3 != null) errs.add(err3.message);
      wallets.add(wallet44!);

      if (wallets.isEmpty) throw 'Unable to create a wallet:\n ${errs.join(', ')}';
      return (wallets, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  static (List<Wallet>?, Err?) fromDescrAll({
    required BBWalletType bbWalletType,
    required bool isTestNet,
    required String descriptor,
    required String changeDescriptor,
    required String fngr,
  }) {
    try {
      final wallets = <Wallet>[];
      final errs = <String>[];

      final (wallet84, err) = Wallet.fromXPubDescr(
        walletPurpose: WalletPurpose.bip84,
        isTestNet: isTestNet,
        bbWalletType: bbWalletType,
        changeDescriptor: changeDescriptor,
        descriptor: descriptor,
        fngr: fngr,
      );

      if (err != null) errs.add(err.message);
      wallets.add(wallet84!);

      final (wallet49, err2) = Wallet.fromXPubDescr(
        walletPurpose: WalletPurpose.bip49,
        isTestNet: isTestNet,
        bbWalletType: bbWalletType,
        changeDescriptor: changeDescriptor,
        descriptor: descriptor,
        fngr: fngr,
      );

      if (err2 != null) errs.add(err2.message);
      wallets.add(wallet49!);

      final (wallet44, err3) = Wallet.fromXPubDescr(
        walletPurpose: WalletPurpose.bip44,
        isTestNet: isTestNet,
        bbWalletType: bbWalletType,
        changeDescriptor: changeDescriptor,
        descriptor: descriptor,
        fngr: fngr,
      );

      if (err3 != null) errs.add(err3.message);
      wallets.add(wallet44!);

      if (wallets.isEmpty) throw 'Unable to create a wallet:\n ${errs.join(', ')}';
      return (wallets, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  static (Wallet?, Err?) fromXPubDescr({
    required BBWalletType bbWalletType,
    required WalletPurpose walletPurpose,
    required bool isTestNet,
    String? descriptor,
    String? changeDescriptor,
    String? xpub,
    required String fngr,
    String? path,
  }) {
    try {
      final bbNetwork = isTestNet ? BBNetwork.Testnet : BBNetwork.Mainnet;
      if (bbWalletType == BBWalletType.descriptors) {
        if (descriptor == null || descriptor.isEmpty) throw 'No descriptor provided';
        if (changeDescriptor == null || changeDescriptor.isEmpty)
          throw 'No change descriptor provided';

        final wallet = Wallet(
          network: bbNetwork,
          type: bbWalletType,
          purpose: walletPurpose,
          externalPublicDescriptor: descriptor,
          internalPublicDescriptor: changeDescriptor,
          path: path,
          fingerprint: fngr,
          backupTested: true,
        );

        return (wallet, null);
      }

      if (xpub == null || xpub.isEmpty) throw 'No xpub provided';
      // if (fngr == null || fngr.isEmpty) throw 'No fingerprint provided';
      if (path == null || path.isEmpty) throw 'No path provided';

      final wallet = Wallet(
        network: bbNetwork,
        type: bbWalletType,
        purpose: walletPurpose,
        xpub: xpub,
        fingerprint: fngr,
        path: path,
        backupTested: true,
      );

      return (wallet, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  static (Wallet?, Err?) fromColdCard({
    required ColdCard coldCard,
    required WalletPurpose walletPurpose,
    required bool isTestNet,
  }) {
    try {
      final isTestNet = coldCard.isTestNet();
      final bbnetwork = isTestNet ? BBNetwork.Testnet : BBNetwork.Mainnet;

      ColdWallet coldWallet;
      String path;

      switch (walletPurpose) {
        case WalletPurpose.bip84:
          coldWallet = coldCard.bip84!;
        case WalletPurpose.bip49:
          coldWallet = coldCard.bip49!;
        case WalletPurpose.bip44:
          coldWallet = coldCard.bip44!;
      }
      path = coldWallet.deriv!;
      final fingerprint = coldCard.xfp!;

      final wallet = Wallet(
        network: bbnetwork,
        type: BBWalletType.coldcard,
        purpose: walletPurpose,
        fingerprint: fingerprint,
        path: path,
        xpub: coldWallet.xpub,
        backupTested: true,
      );

      return (wallet, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  static (Wallet?, Err?) fromMnemonic({
    required String mne,
    required String? password,
    required WalletPurpose walletPurpose,
    required BBWalletType bbWalletType,
    required bool isTestNet,
    required String fngr,
    String? path,
    required bool backupTested,
  }) {
    try {
      final network = isTestNet ? BBNetwork.Testnet : BBNetwork.Mainnet;

      final wallet = Wallet(
        network: network,
        type: bbWalletType,
        purpose: walletPurpose,
        mnemonic: mne,
        password: password,
        path: path,
        fingerprint: fngr,
        backupTested: backupTested,
      );

      return (wallet, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  String cleanFingerprint() {
    if (network == BBNetwork.Testnet) return fingerprint.replaceFirst('tn::', '');
    return fingerprint;
  }

  String getStorageString() {
    var str = fingerprint + '_' + type.name;
    if (network == BBNetwork.Testnet && !str.startsWith('tn')) str = 'tn::$str';
    return str;
  }

  String getStorageString2() {
    var str = fingerprint + '_' + type.name + '_' + type.name;
    if (network == BBNetwork.Testnet && !str.startsWith('tn')) str = 'tn::$str';
    return str;
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

  List<String> mne() {
    return mnemonic.split(' ');
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

    final hasPassword = password != null && password!.isNotEmpty;
    switch (type) {
      case BBWalletType.newSeed:
        str = 'Bull Bitcoin Wallet';
        if (hasPassword)
          str += '\n(Passphase Protected)';
        else
          str += '\n(No passphase)';

      case BBWalletType.xpub:
        str = 'Imported Xpub';
      case BBWalletType.words:
        str = 'Recovered Wallet';
        if (hasPassword)
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
      // return 'Watch Only';
      case BBWalletType.coldcard:
      // return 'Watch Only';

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

String walletNameStr(WalletPurpose purpose) {
  var name = '';
  switch (purpose) {
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
