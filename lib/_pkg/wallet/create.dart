import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/wallet/utils.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:path_provider/path_provider.dart';

class WalletCreate {
  Future<(List<String>?, Err?)> createMne() async {
    try {
      final mne = await bdk.Mnemonic.create(bdk.WordCount.Words12);
      final mneList = mne.asString().split(' ');

      return (mneList, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(String?, Err?)> getMneFingerprint({
    required String mne,
    required bool isTestnet,
    String? password,
    required WalletType walletType,
  }) async {
    try {
      final network = isTestnet ? bdk.Network.Testnet : bdk.Network.Bitcoin;

      final mn = await bdk.Mnemonic.fromString(mne);
      final descriptorSecretKey = await bdk.DescriptorSecretKey.create(
        network: network,
        mnemonic: mn,
        password: password,
      );

      String fgnr;

      switch (walletType) {
        case WalletType.bip84:
          final externalDescriptor = await bdk.Descriptor.newBip84(
            secretKey: descriptorSecretKey,
            network: network,
            keychain: bdk.KeychainKind.External,
          );
          final edesc = await externalDescriptor.asString();
          fgnr = fingerPrintFromDescr(edesc, isTesnet: isTestnet);

        case WalletType.bip44:
          final externalDescriptor = await bdk.Descriptor.newBip44(
            secretKey: descriptorSecretKey,
            network: network,
            keychain: bdk.KeychainKind.External,
          );
          final edesc = await externalDescriptor.asString();
          fgnr = fingerPrintFromDescr(edesc, isTesnet: isTestnet);

        case WalletType.bip49:
          final externalDescriptor = await bdk.Descriptor.newBip49(
            secretKey: descriptorSecretKey,
            network: network,
            keychain: bdk.KeychainKind.External,
          );
          final edesc = await externalDescriptor.asString();
          fgnr = fingerPrintFromDescr(edesc, isTesnet: isTestnet);
      }

      return (fgnr, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<((Wallet, bdk.Wallet)?, Err?)> loadBdkWallet(
    Wallet wallet, {
    bool fromStorage = true,
  }) async {
    try {
      final network = wallet.network == BBNetwork.Testnet
          ? bdk.Network.Testnet
          : bdk.Network.Bitcoin;
      final walletType = wallet.walletType;
      // final eternalDescr = wallet.externalDescriptor;
      // String? iDesc;
      // final isTestNet = wallet.network == BBNetwork.Testnet;

      bdk.Descriptor? internal;
      bdk.Descriptor? external;
      switch (wallet.type) {
        case BBWalletType.words:
        case BBWalletType.newSeed:
          final mnemo = await bdk.Mnemonic.fromString(wallet.mnemonic);

          var descriptor = await bdk.DescriptorSecretKey.create(
            network: network,
            mnemonic: mnemo,
            password: wallet.password,
          );

          if (wallet.path != null) {
            final derivation =
                await bdk.DerivationPath.create(path: wallet.path!);
            descriptor = await descriptor.derive(derivation);
          }

          switch (walletType) {
            case WalletType.bip84:
              internal = await bdk.Descriptor.newBip84(
                secretKey: descriptor,
                network: network,
                keychain: bdk.KeychainKind.Internal,
              );

              external = await bdk.Descriptor.newBip84(
                secretKey: descriptor,
                network: network,
                keychain: bdk.KeychainKind.External,
              );
            case WalletType.bip49:
              internal = await bdk.Descriptor.newBip49(
                secretKey: descriptor,
                network: network,
                keychain: bdk.KeychainKind.Internal,
              );

              external = await bdk.Descriptor.newBip49(
                secretKey: descriptor,
                network: network,
                keychain: bdk.KeychainKind.External,
              );
            case WalletType.bip44:
              internal = await bdk.Descriptor.newBip44(
                secretKey: descriptor,
                network: network,
                keychain: bdk.KeychainKind.Internal,
              );

              external = await bdk.Descriptor.newBip44(
                secretKey: descriptor,
                network: network,
                keychain: bdk.KeychainKind.External,
              );
          }

        case BBWalletType.coldcard:
        case BBWalletType.xpub:
          // final fngr = fingerPrintFromDescr(
          //   eternalDescr,
          //   isTesnet: isTestNet,
          //   ignorePrefix: true,
          // );
          // final key = keyFromDescr(eternalDescr);

          final fngr = wallet.fingerprint;

          var pubKey = await bdk.DescriptorPublicKey.fromString(wallet.xpub!);

          // final internalDescriptor =
          //     await bdk.DescriptorPublicKey.fromString(wallet.internalDescriptor);

          if (wallet.path != null) {
            final derivation =
                await bdk.DerivationPath.create(path: wallet.path!);
            pubKey = await pubKey.derive(derivation);
          }

          switch (walletType) {
            case WalletType.bip84:
              internal = await bdk.Descriptor.newBip84Public(
                fingerPrint: fngr,
                publicKey: pubKey,
                network: network,
                keychain: bdk.KeychainKind.Internal,
              );

              external = await bdk.Descriptor.newBip84Public(
                fingerPrint: fngr,
                publicKey: pubKey,
                network: network,
                keychain: bdk.KeychainKind.External,
              );
            case WalletType.bip49:
              internal = await bdk.Descriptor.newBip49Public(
                fingerPrint: fngr,
                publicKey: pubKey,
                network: network,
                keychain: bdk.KeychainKind.Internal,
              );

              external = await bdk.Descriptor.newBip49Public(
                fingerPrint: fngr,
                publicKey: pubKey,
                network: network,
                keychain: bdk.KeychainKind.External,
              );
            case WalletType.bip44:
              internal = await bdk.Descriptor.newBip44Public(
                fingerPrint: fngr,
                publicKey: pubKey,
                network: network,
                keychain: bdk.KeychainKind.Internal,
              );

              external = await bdk.Descriptor.newBip44Public(
                fingerPrint: fngr,
                publicKey: pubKey,
                network: network,
                keychain: bdk.KeychainKind.External,
              );
          }
        case BBWalletType.descriptors:
          external = await bdk.Descriptor.create(
            descriptor: wallet.externalDescriptor,
            network: network,
          );
          internal = await bdk.Descriptor.create(
            descriptor: wallet.internalDescriptor,
            network: network,
          );
      }

      bdk.DatabaseConfig dbConfig;
      if (!fromStorage)
        dbConfig = const bdk.DatabaseConfig.memory();
      else {
        final appDocDir = await getApplicationDocumentsDirectory();
        final dbDir = appDocDir.path + '/${wallet.getStorageString()}';
        dbConfig = bdk.DatabaseConfig.sqlite(
          config: bdk.SqliteDbConfiguration(path: dbDir),
        );
      }

      final bdkWallet = await bdk.Wallet.create(
        descriptor: external,
        changeDescriptor: internal,
        network: network,
        databaseConfig: dbConfig,
      );

      return ((wallet, bdkWallet), null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(bdk.Blockchain?, Err?)> createBlockChain({
    required int stopGap,
    required int timeout,
    required int retry,
    required String url,
    required bool validateDomain,
  }) async {
    try {
      final blockchain = await bdk.Blockchain.create(
        config: bdk.BlockchainConfig.electrum(
          config: bdk.ElectrumConfig(
            url: url,
            retry: retry,
            timeout: timeout,
            stopGap: stopGap,
            validateDomain: validateDomain,
          ),
        ),
      );

      return (blockchain, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }
}

//
//
//
//
//
//
//
// //
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//

// Future<(Wallet?, Err?)> saveWalletFromColdCard({
//   required ColdCard coldCard,
//   required WalletType walletType,
//   // String? path,
//   required WalletUpdate walletUpdate,
//   required IStorage storage,
// }) async {
//   try {
//     final isTestNet = coldCard.isTestNet();
//     final bbnetwork = isTestNet ? BBNetwork.Testnet : BBNetwork.Mainnet;
//     final network = isTestNet ? bdk.Network.Testnet : bdk.Network.Bitcoin;

//     ColdWallet coldWallet;
//     String path;

//     switch (walletType) {
//       case WalletType.bip84:
//         coldWallet = coldCard.bip84!;
//       case WalletType.bip49:
//         coldWallet = coldCard.bip49!;
//       case WalletType.bip44:
//         coldWallet = coldCard.bip44!;
//     }
//     path = coldWallet.deriv!;
//     final ed = coldWallet.xpub! + '/' + path.replaceFirst('m/', '') + '/0/*';
//     final edescriptor = await bdk.DescriptorPublicKey.fromString(ed);
//     final id = coldWallet.xpub! + '/' + path.replaceFirst('m/', '') + '/1/*';
//     final idescriptor = await bdk.DescriptorPublicKey.fromString(id);

//     // if (coldWallet.deriv != null) {
//     //   final derivation = await bdk.DerivationPath.create(path: coldWallet.deriv!);
//     //   descriptor = await descriptor.derive(derivation);
//     // }

//     // final pubkey = descriptor.asString();

//     final fingerprint = coldWallet.xfp!;
//     // final fingerPrintNew = fingerPrintFromDescr(pubkey, isTesnet: isTestNet);

//     bdk.Descriptor external;
//     bdk.Descriptor internal;
//     switch (walletType) {
//       case WalletType.bip84:
//         external = await bdk.Descriptor.newBip84Public(
//           fingerPrint: fingerprint,
//           publicKey: edescriptor,
//           network: network,
//           keychain: bdk.KeychainKind.External,
//         );

//         internal = await bdk.Descriptor.newBip84Public(
//           fingerPrint: fingerprint,
//           publicKey: idescriptor,
//           network: network,
//           keychain: bdk.KeychainKind.Internal,
//         );
//       case WalletType.bip49:
//         external = await bdk.Descriptor.newBip49Public(
//           fingerPrint: fingerprint,
//           publicKey: edescriptor,
//           network: network,
//           keychain: bdk.KeychainKind.External,
//         );

//         internal = await bdk.Descriptor.newBip49Public(
//           fingerPrint: fingerprint,
//           publicKey: idescriptor,
//           network: network,
//           keychain: bdk.KeychainKind.Internal,
//         );

//       case WalletType.bip44:
//         external = await bdk.Descriptor.newBip44Public(
//           fingerPrint: fingerprint,
//           publicKey: edescriptor,
//           network: network,
//           keychain: bdk.KeychainKind.External,
//         );

//         internal = await bdk.Descriptor.newBip44Public(
//           fingerPrint: fingerprint,
//           publicKey: idescriptor,
//           network: network,
//           keychain: bdk.KeychainKind.Internal,
//         );
//     }

//     final eDescr = await external.asString();
//     // final iDescr = await internal.asString();

//     final fingerPrintToSave = fingerPrintFromDescr(eDescr, isTesnet: isTestNet);

//     final appDocDir = await getApplicationDocumentsDirectory();
//     final walletTyppe = walletType.name;
//     final dbDir = appDocDir.path + '/$fingerPrintToSave' + '_$walletTyppe';

//     await bdk.Wallet.create(
//       descriptor: external,
//       changeDescriptor: internal,
//       network: network,
//       databaseConfig: bdk.DatabaseConfig.sqlite(
//         config: bdk.SqliteDbConfiguration(path: dbDir),
//       ),
//     );

//     final wallet = Wallet(
//       fingerprint: fingerPrintToSave,
//       externalDescriptor: ed,
//       internalDescriptor: id,
//       path: path,
//       network: bbnetwork,
//       type: BBWalletType.coldcard,
//       walletType: walletType,
//       backupTested: true,
//     );
//     final err = await walletUpdate.addWalletToList(
//       wallet: wallet,
//       storage: storage,
//     );
//     if (err != null) return (null, err);

//     final w = wallet.copyWith(
//       mnemonic: '',
//       password: '',
//     );

//     return (w, null);
//   } catch (e) {
//     return (null, Err(e.toString()));
//   }
// }

//
//

// final ed = coldWallet.xpub! + '/' + path.replaceFirst('m/', '') + '/0/*';

// final edescriptor = await bdk.DescriptorPublicKey.fromString(ed);
// final id = coldWallet.xpub! + '/' + path.replaceFirst('m/', '') + '/1/*';
// final idescriptor = await bdk.DescriptorPublicKey.fromString(id);

// if (coldWallet.deriv != null) {
//   final derivation = await bdk.DerivationPath.create(path: coldWallet.deriv!);
//   descriptor = await descriptor.derive(derivation);
// }

// final pubkey = descriptor.asString();

// final network = coldCard.isTestNet() ? bdk.Network.Testnet : bdk.Network.Bitcoin;

// ColdWallet coldWallet;
// String displayPath;

// switch (walletType) {
//   case WalletType.bip84:
//     if (coldCard.bip44 == null) throw 'No wallet';
//     coldWallet = coldCard.bip44!;
//   case WalletType.bip49:
//     if (coldCard.bip49 == null) throw 'No wallet';
//     coldWallet = coldCard.bip49!;
//   case WalletType.bip44:
//     if (coldCard.bip84 == null) throw 'No wallet';
//     coldWallet = coldCard.bip84!;
// }
// displayPath = coldWallet.deriv!;
// final external = await bdk.DescriptorPublicKey.fromString(
//   coldWallet.xpub! + '/' + displayPath.replaceFirst('m/', '') + '/0/*',
// );

// // if (coldWallet.deriv != null) {
// //   final der = coldWallet.deriv!;
// //   final derivation = await bdk.DerivationPath.create(path: der);
// //   external = await external.derive(derivation);
// // }

// final fingerprint = coldWallet.xfp!;

// bdk.Descriptor descriptor;
// switch (walletType) {
//   case WalletType.bip84:
//     descriptor = await bdk.Descriptor.newBip84Public(
//       fingerPrint: fingerprint,
//       publicKey: external,
//       network: network,
//       keychain: bdk.KeychainKind.External,
//     );
//   case WalletType.bip49:
//     descriptor = await bdk.Descriptor.newBip49Public(
//       fingerPrint: fingerprint,
//       publicKey: external,
//       network: network,
//       keychain: bdk.KeychainKind.External,
//     );

//   case WalletType.bip44:
//     descriptor = await bdk.Descriptor.newBip44Public(
//       fingerPrint: fingerprint,
//       publicKey: external,
//       network: network,
//       keychain: bdk.KeychainKind.External,
//     );
// }

// final eDescr = await descriptor.asString();
// final fngr = fingerPrintFromDescr(eDescr, isTesnet: isTestNet, ignorePrefix: true);

// var firstAddress = coldWallet.first;
// if (firstAddress == null) {
//   final wallet = await bdk.Wallet.create(
//     descriptor: descriptor,
//     network: isTestNet ? bdk.Network.Testnet : bdk.Network.Bitcoin,
//     databaseConfig: const bdk.DatabaseConfig.memory(),
//   );
//   final address = await wallet.getAddress(
//     addressIndex: const bdk.AddressIndex.peek(index: 0),
//   );

//   firstAddress = address.address;
// }

// final pubkey = external.asString();

// final walletDetails = WalletDetails(
//   firstAddress: firstAddress,
//   fingerPrint: fngr,
//   expandedPubKey: pubkey,
//   derivationPath: displayPath,
//   type: walletType,
// );

// return (walletDetails, null);

// Future<(Wallet?, Err?)> saveWalletFromMne({
//   required String mne,
//   required String? password,
//   required WalletType walletType,
//   required bool isTestNet,
//   String? path,
//   required WalletUpdate walletUpdate,
//   required IStorage storage,
//   required BBWalletType bbWalletType,
// }) async {
//   try {
//     final network = isTestNet ? bdk.Network.Testnet : bdk.Network.Bitcoin;

//     final mnemo = await bdk.Mnemonic.fromString(mne);
//     var descriptorKey = await bdk.DescriptorSecretKey.create(
//       network: network,
//       mnemonic: mnemo,
//       password: password,
//     );

//     if (path != null) {
//       final derivation = await bdk.DerivationPath.create(path: path);
//       descriptorKey = await descriptorKey.derive(derivation);
//     }

//     bdk.Descriptor internal;
//     bdk.Descriptor external;

//     switch (walletType) {
//       case WalletType.bip84:
//         internal = await bdk.Descriptor.newBip84(
//           secretKey: descriptorKey,
//           network: network,
//           keychain: bdk.KeychainKind.Internal,
//         );
//         external = await bdk.Descriptor.newBip84(
//           secretKey: descriptorKey,
//           network: network,
//           keychain: bdk.KeychainKind.External,
//         );

//       case WalletType.bip49:
//         internal = await bdk.Descriptor.newBip49(
//           secretKey: descriptorKey,
//           network: network,
//           keychain: bdk.KeychainKind.Internal,
//         );
//         external = await bdk.Descriptor.newBip49(
//           secretKey: descriptorKey,
//           network: network,
//           keychain: bdk.KeychainKind.External,
//         );
//       case WalletType.bip44:
//         internal = await bdk.Descriptor.newBip44(
//           secretKey: descriptorKey,
//           network: network,
//           keychain: bdk.KeychainKind.Internal,
//         );
//         external = await bdk.Descriptor.newBip44(
//           secretKey: descriptorKey,
//           network: network,
//           keychain: bdk.KeychainKind.External,
//         );
//     }

//     final edesc = await external.asString();
//     final idesc = await internal.asStringPrivate();
//     // final pub = keyFromDescr(edesc);

//     final fingerPrint = fingerPrintFromDescr(edesc, isTesnet: isTestNet);
//     final appDocDir = await getApplicationDocumentsDirectory();
//     final walletTyppe = walletType.name;
//     final dbDir = appDocDir.path + '/$fingerPrint' + '_$walletTyppe';

//     await bdk.Wallet.create(
//       descriptor: external,
//       changeDescriptor: internal,
//       network: network,
//       databaseConfig: bdk.DatabaseConfig.sqlite(
//         config: bdk.SqliteDbConfiguration(path: dbDir),
//       ),
//     );

//     final wallet = Wallet(
//       fingerprint: fingerPrint,
//       mnemonic: mne,
//       password: password,
//       externalDescriptor: edesc,
//       internalDescriptor: idesc,
//       network: isTestNet ? BBNetwork.Testnet : BBNetwork.Mainnet,
//       type: bbWalletType,
//       walletType: walletType,
//       backupTested: bbWalletType != BBWalletType.newSeed,
//     );

//     final err = await walletUpdate.addWalletToList(
//       wallet: wallet,
//       storage: storage,
//     );
//     if (err != null) return (null, err);

//     final w = wallet.copyWith(
//       mnemonic: '',
//       password: '',
//     );
//     return (w, null);
//   } catch (e) {
//     return (
//       null,
//       Err(e.toString()),
//     );
//   }
// }

// final fngr = wallet.cleanFingerprint();
// // fingerPrintFromDescr(eternalDescr, isTesnet: isTestNet, ignorePrefix: true);
// final key = keyFromDescr(wallet.externalDescriptor);

// final externalDescriptor = await bdk.DescriptorPublicKey.fromString(key);

// final internalDescriptor =
//     await bdk.DescriptorPublicKey.fromString(wallet.internalDescriptor);

// // if (wallet.path != null) {
// //   final derivation = await bdk.DerivationPath.create(path: wallet.path!);
// //   internalDescriptor = await internalDescriptor.derive(derivation);
// // }

// switch (walletType) {
//   case WalletType.bip84:
//     internal = await bdk.Descriptor.newBip84Public(
//       fingerPrint: fngr,
//       publicKey: internalDescriptor,
//       network: network,
//       keychain: bdk.KeychainKind.Internal,
//     );

//     external = await bdk.Descriptor.newBip84Public(
//       fingerPrint: fngr,
//       publicKey: externalDescriptor,
//       network: network,
//       keychain: bdk.KeychainKind.External,
//     );
//   case WalletType.bip49:
//     internal = await bdk.Descriptor.newBip49Public(
//       fingerPrint: fngr,
//       publicKey: internalDescriptor,
//       network: network,
//       keychain: bdk.KeychainKind.Internal,
//     );

//     external = await bdk.Descriptor.newBip49Public(
//       fingerPrint: fngr,
//       publicKey: externalDescriptor,
//       network: network,
//       keychain: bdk.KeychainKind.External,
//     );
//   case WalletType.bip44:
//     internal = await bdk.Descriptor.newBip44Public(
//       fingerPrint: fngr,
//       publicKey: internalDescriptor,
//       network: network,
//       keychain: bdk.KeychainKind.Internal,
//     );

//     external = await bdk.Descriptor.newBip44Public(
//       fingerPrint: fngr,
//       publicKey: externalDescriptor,
//       network: network,
//       keychain: bdk.KeychainKind.External,
//     );
// }
//

//
//
// if (wallet.type == BBWalletType.words || wallet.type == BBWalletType.newSeed) {
// } else if (wallet.type == BBWalletType.coldcard) {
// } else if (wallet.type == BBWalletType.xpub) {}

// final eDesc = await external!.asString();
// final fingerprint = wallet.fingerprint;

// final w = wallet.copyWith(
//     // externalDescriptor: eDesc,
//     // internalDescriptor: iDesc ?? '',
//     );
//
//

// final network = isTestNet ? bdk.Network.Testnet : bdk.Network.Bitcoin;

// final mnemo = await bdk.Mnemonic.fromString(mne);
// var descriptorKey = await bdk.DescriptorSecretKey.create(
//   network: network,
//   mnemonic: mnemo,
//   password: password,
// );

// if (path != null) {
//   final derivation = await bdk.DerivationPath.create(path: path);
//   descriptorKey = await descriptorKey.derive(derivation);
// }

// final xpub = await descriptorKey.asPublic();
// final pub = xpub.asString();

// final key = keyFromDescr(pub);

// bdk.Descriptor internal;
// bdk.Descriptor external;

// String displayPath;
// switch (walletType) {
//   case WalletType.bip84:
//     internal = await bdk.Descriptor.newBip84(
//       secretKey: descriptorKey,
//       network: network,
//       keychain: bdk.KeychainKind.Internal,
//     );
//     external = await bdk.Descriptor.newBip84(
//       secretKey: descriptorKey,
//       network: network,
//       keychain: bdk.KeychainKind.External,
//     );
//     displayPath = "m/84'/0'/0'/*";

//   case WalletType.bip49:
//     internal = await bdk.Descriptor.newBip49(
//       secretKey: descriptorKey,
//       network: network,
//       keychain: bdk.KeychainKind.Internal,
//     );
//     external = await bdk.Descriptor.newBip49(
//       secretKey: descriptorKey,
//       network: network,
//       keychain: bdk.KeychainKind.External,
//     );
//     displayPath = "m/49'/0'/0'/*";
//   case WalletType.bip44:
//     internal = await bdk.Descriptor.newBip44(
//       secretKey: descriptorKey,
//       network: network,
//       keychain: bdk.KeychainKind.Internal,
//     );
//     external = await bdk.Descriptor.newBip44(
//       secretKey: descriptorKey,
//       network: network,
//       keychain: bdk.KeychainKind.External,
//     );
//     displayPath = "m/84'/0'/0'/*";
// }

// final wallet = await bdk.Wallet.create(
//   descriptor: external,
//   changeDescriptor: internal,
//   network: network,
//   databaseConfig: const bdk.DatabaseConfig.memory(),
// );

// final firstAddress = await wallet.getAddress(
//   addressIndex: const bdk.AddressIndex.peek(index: 0),
// );

// // wpkh([ddffda99/84'/1'/0']tpubDDnLoUnx37yzHvcifbUWBmdGmQj1ZGVEtZgLSAHgzqLF4en9ZSAf9MuvEah3NrSUoAhHW8UnERsHeyumfqCt1RiY4JBcuRYwBEEAgFd8xQh/0/*)#e6cds43y
// final exDescr = await external.asString();
// final fingerPrint = fingerPrintFromDescr(
//   exDescr,
//   isTesnet: isTestNet,
//   ignorePrefix: true,
// );

// final walletDetails = WalletDetails(
//   firstAddress: firstAddress.address,
//   fingerPrint: fingerPrint,
//   expandedPubKey: key,
//   derivationPath: path ?? displayPath,
//   type: walletType,
// );

// return (walletDetails, null);

// Future<(WalletDetails?, String?)> createPublicWalletDetails({
//   required String xpub,
//   required WalletType walletType,
//   required bool isTestNet,
//   String? path,
//   String? fingerprint,
// }) async {
//   try {
//     final network = isTestNet ? bdk.Network.Testnet : bdk.Network.Bitcoin;

//     var descriptorKey = await bdk.DescriptorPublicKey.fromString(xpub);

//     if (path != null) {
//       final derivation = await bdk.DerivationPath.create(path: path);
//       descriptorKey = await descriptorKey.derive(derivation);
//     } else {
//       final derivation = await bdk.DerivationPath.create(path: 'm/1/0');
//       descriptorKey = await descriptorKey.derive(derivation);
//     }

//     final fingerPrint = fingerprint ??
//         fingerPrintFromDescr(
//           descriptorKey.asString(),
//           isTesnet: isTestNet,
//           ignorePrefix: true,
//         );

//     bdk.Descriptor descriptor;
//     String displayPath;
//     switch (walletType) {
//       case WalletType.bip84:
//         descriptor = await bdk.Descriptor.newBip84Public(
//           fingerPrint: fingerPrint,
//           publicKey: descriptorKey,
//           network: network,
//           keychain: bdk.KeychainKind.External,
//         );
//         displayPath = "m/84'/0'/0'/*";

//       case WalletType.bip49:
//         descriptor = await bdk.Descriptor.newBip49Public(
//           fingerPrint: fingerPrint,
//           publicKey: descriptorKey,
//           network: network,
//           keychain: bdk.KeychainKind.External,
//         );
//         displayPath = "m/49'/0'/0'/*";
//       case WalletType.bip44:
//         descriptor = await bdk.Descriptor.newBip44Public(
//           fingerPrint: fingerPrint,
//           publicKey: descriptorKey,
//           network: network,
//           keychain: bdk.KeychainKind.External,
//         );
//         displayPath = "m/44'/0'/0'/*";
//     }

//     final eDescr = await descriptor.asString();
//     final fngr = fingerPrintFromDescr(eDescr, isTesnet: isTestNet, ignorePrefix: true);

//     final wallet = await bdk.Wallet.create(
//       descriptor: descriptor,
//       network: isTestNet ? bdk.Network.Testnet : bdk.Network.Bitcoin,
//       // network: bdk.Network.Bitcoin,
//       databaseConfig: const bdk.DatabaseConfig.memory(),
//     );

//     final firstAddress = await wallet.getAddress(
//       addressIndex: const bdk.AddressIndex.peek(index: 0),
//     );

//     final key = keyFromDescr(eDescr);

//     final walletDetails = WalletDetails(
//       firstAddress: firstAddress.address,
//       fingerPrint: fngr,
//       expandedPubKey: key,
//       derivationPath: path ?? displayPath,
//       type: walletType,
//     );

//     return (walletDetails, null);
//   } catch (e) {
//     return (null, e.toString());
//   }
// }

// Future<(WalletDetails?, Err?)> createPublicWalletDetails2({
//   required String xpub,
//   String? descriptor,
//   required WalletType walletType,
//   required bool isTestNet,
//   String? path,
//   String? fingerprint,
//   // int? accountNumber,
//   bool isHardened = false,
// }) async {
//   try {
//     final coinType = isTestNet ? '1' : '0';
//     // final account = (accountNumber ?? 0).toString();

//     String descStr = '';
//     String displayPath;

//     // switch (walletType) {
//     //   case WalletType.bip84:
//     //     descStr = 'wpkh($xpub/$coinType/$account/*)';
//     //     displayPath = "m/84'/$coinType/$account/*";

//     //   case WalletType.bip49:
//     //     descStr = 'sh(wpkh($xpub/$coinType/$account/*))';
//     //     displayPath = "m/49'/$coinType/$account/*";

//     //   case WalletType.bip44:
//     //     descStr = 'pkh($xpub/$coinType/$account/*)';
//     //     displayPath = "m/44'/$coinType/$account/*";
//     // }

//     final descriptor = await bdk.Descriptor.create(
//       descriptor: descStr,
//       network: bdk.Network.Testnet,
//     );

//     // final eDescr = await descriptor.asString();
//     // final epr = await descriptor.asStringPrivate();
//     // print('---eDescr: $eDescr');
//     // print('---epr: $epr');

//     // final fngr = fingerPrintFromDescr(eDescr, isTesnet: isTestNet, ignorePrefix: true);

//     final wallet = await bdk.Wallet.create(
//       descriptor: descriptor,
//       network: isTestNet ? bdk.Network.Testnet : bdk.Network.Bitcoin,
//       // network: bdk.Network.Bitcoin,
//       databaseConfig: const bdk.DatabaseConfig.memory(),
//     );
//     final e = await wallet.getDescriptorForKeyChain(bdk.KeychainKind.External);
//     final s = await e.asString();
//     final p = await e.asStringPrivate();
//     print('---ed: $s');
//     print('---ep: $p');
//     final r = await wallet.getDescriptorForKeyChain(bdk.KeychainKind.Internal);
//     final rs = await r.asString();
//     final rp = await r.asStringPrivate();

//     print('---rd: $rs');
//     print('---rp: $rp');

//     final firstAddress = await wallet.getAddress(
//       addressIndex: const bdk.AddressIndex.peek(index: 0),
//     );

//     // final key = keyFromDescr(eDescr);

//     final walletDetails = WalletDetails(
//       firstAddress: firstAddress.address,
//       fingerPrint: '',
//       // expandedPubKey: key,
//       derivationPath: path ?? 'displayPath',
//       type: walletType,
//     );

//     return (walletDetails, null);
//   } catch (e) {
//     return (null, Err(e.toString()));
//   }
// }

// Future<(Wallet?, Err?)> saveWalletFromXPub({
//   required String xpub,
//   required WalletType walletType,
//   required bool isTestNet,
//   required String fngr,
//   String? path,
//   required WalletUpdate walletUpdate,
//   required IStorage storage,
// }) async {
//   try {
//     final network = isTestNet ? bdk.Network.Testnet : bdk.Network.Bitcoin;

//     var descriptorKey = await bdk.DescriptorPublicKey.fromString(xpub);

//     if (path != null) {
//       final derivation = await bdk.DerivationPath.create(path: path);
//       descriptorKey = await descriptorKey.derive(derivation);
//     }

//     final pubKey = descriptorKey.asString();

//     final fingerPrint = fngr.isEmpty
//         ? fingerPrintFromDescr(pubKey, isTesnet: isTestNet, ignorePrefix: true)
//         : fngr;

//     bdk.Descriptor internal;
//     bdk.Descriptor external;

//     switch (walletType) {
//       case WalletType.bip84:
//         external = await bdk.Descriptor.newBip84Public(
//           fingerPrint: fingerPrint,
//           publicKey: descriptorKey,
//           network: network,
//           keychain: bdk.KeychainKind.External,
//         );

//         internal = await bdk.Descriptor.newBip84Public(
//           fingerPrint: fingerPrint,
//           publicKey: descriptorKey,
//           network: network,
//           keychain: bdk.KeychainKind.Internal,
//         );

//       case WalletType.bip49:
//         external = await bdk.Descriptor.newBip49Public(
//           fingerPrint: fingerPrint,
//           publicKey: descriptorKey,
//           network: network,
//           keychain: bdk.KeychainKind.External,
//         );

//         internal = await bdk.Descriptor.newBip49Public(
//           fingerPrint: fingerPrint,
//           publicKey: descriptorKey,
//           network: network,
//           keychain: bdk.KeychainKind.Internal,
//         );
//       case WalletType.bip44:
//         external = await bdk.Descriptor.newBip44Public(
//           fingerPrint: fingerPrint,
//           publicKey: descriptorKey,
//           network: network,
//           keychain: bdk.KeychainKind.External,
//         );

//         internal = await bdk.Descriptor.newBip44Public(
//           fingerPrint: fingerPrint,
//           publicKey: descriptorKey,
//           network: network,
//           keychain: bdk.KeychainKind.Internal,
//         );
//     }

//     final eDescr = await external.asString();

//     final fingerPrintToSave = fingerPrintFromDescr(eDescr, isTesnet: isTestNet);

//     final appDocDir = await getApplicationDocumentsDirectory();
//     final walletTyppe = walletType.name;
//     final dbDir = appDocDir.path + '/$fingerPrintToSave' + '_$walletTyppe';

//     await bdk.Wallet.create(
//       descriptor: external,
//       changeDescriptor: internal,
//       network: network,
//       databaseConfig: bdk.DatabaseConfig.sqlite(
//         config: bdk.SqliteDbConfiguration(path: dbDir),
//       ),
//     );

//     final wallet = Wallet(
//       fingerprint: fingerPrintToSave,
//       externalDescriptor: eDescr,
//       path: path,
//       network: isTestNet ? BBNetwork.Testnet : BBNetwork.Mainnet,
//       type: BBWalletType.xpub,
//       walletType: walletType,
//       backupTested: true,
//     );
//     final err = await walletUpdate.addWalletToList(
//       wallet: wallet,
//       storage: storage,
//     );
//     if (err != null) return (null, err);

//     final w = wallet.copyWith(
//       mnemonic: '',
//       password: '',
//     );

//     return (w, null);
//   } catch (e) {
//     return (null, Err(e.toString()));
//   }
// }

// required WalletUpdate walletUpdate,
// required IStorage storage,
//   final network = isTestNet ? bdk.Network.Testnet : bdk.Network.Bitcoin;

//   var descriptorKey = await bdk.DescriptorPublicKey.fromString(xpub);

//   final derivation = await bdk.DerivationPath.create(path: path);
//   descriptorKey = await descriptorKey.derive(derivation);

// final cdescriptor = await bdk.Descriptor.newBip44Public(
//   fingerPrint: fngr,
//   publicKey: descriptorKey,
//   network: network,
//   keychain: bdk.KeychainKind.Internal,
// );

// final descriptor = await bdk.Descriptor.newBip44Public(
//   fingerPrint: fngr,
//   publicKey: descriptorKey,
//   network: network,
//   keychain: bdk.KeychainKind.External,
// );

// throw '';

// final network = isTestNet ? bdk.Network.Testnet : bdk.Network.Bitcoin;

// final internal = await bdk.Descriptor.create(descriptor: changeDescriptor, network: network);
// final external = await bdk.Descriptor.create(descriptor: descriptor, network: network);

// var descriptorKey = await bdk.DescriptorPublicKey.fromString(xpub);

// if (path != null) {
//   final derivation = await bdk.DerivationPath.create(path: path);
//   descriptorKey = await descriptorKey.derive(derivation);
// }

// final pubKey = descriptorKey.asString();

// final fingerPrint = fngr.isEmpty
//     ? fingerPrintFromDescr(pubKey, isTesnet: isTestNet, ignorePrefix: true)
//     : fngr;

// bdk.Descriptor internal;
// bdk.Descriptor external;

// switch (walletType) {
//   case WalletType.bip84:
//     external = await bdk.Descriptor.newBip84Public(
//       fingerPrint: fingerPrint,
//       publicKey: descriptorKey,
//       network: network,
//       keychain: bdk.KeychainKind.External,
//     );

//     internal = await bdk.Descriptor.newBip84Public(
//       fingerPrint: fingerPrint,
//       publicKey: descriptorKey,
//       network: network,
//       keychain: bdk.KeychainKind.Internal,
//     );

//   case WalletType.bip49:
//     external = await bdk.Descriptor.newBip49Public(
//       fingerPrint: fingerPrint,
//       publicKey: descriptorKey,
//       network: network,
//       keychain: bdk.KeychainKind.External,
//     );

//     internal = await bdk.Descriptor.newBip49Public(
//       fingerPrint: fingerPrint,
//       publicKey: descriptorKey,
//       network: network,
//       keychain: bdk.KeychainKind.Internal,
//     );
//   case WalletType.bip44:
//     external = await bdk.Descriptor.newBip44Public(
//       fingerPrint: fingerPrint,
//       publicKey: descriptorKey,
//       network: network,
//       keychain: bdk.KeychainKind.External,
//     );

//     internal = await bdk.Descriptor.newBip44Public(
//       fingerPrint: fingerPrint,
//       publicKey: descriptorKey,
//       network: network,
//       keychain: bdk.KeychainKind.Internal,
//     );
// }

// final eDescr = await external.asString();

// final fingerPrintToSave = getRandString(6);
// // fingerPrintFromDescr(eDescr, isTesnet: isTestNet);

// final appDocDir = await getApplicationDocumentsDirectory();
// final walletTyppe = walletType.name;
// final dbDir = appDocDir.path + '/$fingerPrintToSave' + '_$walletTyppe';

// await bdk.Wallet.create(
//   descriptor: external,
//   changeDescriptor: internal,
//   network: network,
//   databaseConfig: bdk.DatabaseConfig.sqlite(
//     config: bdk.SqliteDbConfiguration(path: dbDir),
//   ),
// );

// final wallet = Wallet(
//   fingerprint: fingerPrintToSave,
//   externalDescriptor: descriptor,
//   // path: path,
//   network: isTestNet ? BBNetwork.Testnet : BBNetwork.Mainnet,
//   type: BBWalletType.xpub,
//   walletType: walletType,
//   backupTested: true,
// );
// final err = await walletUpdate.addWalletToList(
//   wallet: wallet,
//   storage: storage,
// );
// if (err != null) return (null, err);

// final w = wallet.copyWith(
//   mnemonic: '',
//   password: '',
// );

// return (w, null);

// final coinType = isTestNet ? '1' : '0';
// final purpose = walletType.walletNumber();

// final fngr = fingerprint != null ? "[$fingerprint/$purpose'/$coinType'/$account']" : '';
// if (path == null && accountNumber > 0) endPath = "/$purpose'/$coinType'/$account'/$change/*";
// path != null ? '/$path/$change/*' :
// if (!isHardened) descriptor = descriptor.replaceAll("'", '');

// remove m
// replace h with '
// with zpub dont accept path or fingerprint
//
// check 3 parts
// 1. 44, etc
// 2. 0, 1
// 3. any number
