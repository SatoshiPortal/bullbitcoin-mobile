// import 'package:bb_mobile/_model/seed.dart';
// import 'package:bb_mobile/_model/wallet.dart';
// import 'package:bb_mobile/_pkg/error.dart';
// import 'package:bb_mobile/_pkg/logger.dart';
// import 'package:bb_mobile/_pkg/wallet/sensitive/create.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:get_it/get_it.dart';
// import 'package:mockito/mockito.dart';
// import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// import 'package:plugin_platform_interface/plugin_platform_interface.dart';
// import 'package:test/test.dart';

// import './wallet_sensitive_create_test.data.dart';

// const String kTemporaryPath = 'temporaryPath';
// const String kApplicationSupportPath = 'applicationSupportPath';
// const String kDownloadsPath = 'downloadsPath';
// const String kLibraryPath = 'libraryPath';
// const String kApplicationDocumentsPath = '/Users/saiy2k/bb/bullbitcoin-mobile/temp';
// const String kExternalCachePath = 'externalCachePath';
// const String kExternalStoragePath = 'externalStoragePath';

// class FakePathProviderPlatform extends Fake
//     with MockPlatformInterfaceMixin
//     implements PathProviderPlatform {
//   @override
//   Future<String?> getTemporaryPath() async {
//     return kTemporaryPath;
//   }

//   @override
//   Future<String?> getApplicationSupportPath() async {
//     return kApplicationSupportPath;
//   }

//   @override
//   Future<String?> getLibraryPath() async {
//     return kLibraryPath;
//   }

//   @override
//   Future<String?> getApplicationDocumentsPath() async {
//     return kApplicationDocumentsPath;
//   }

//   // @override
//   // Future<String?> getApplicationDocumentsDirectory() async {
//   //   return kApplicationDocumentsPath;
//   // }

//   @override
//   Future<String?> getExternalStoragePath() async {
//     return kExternalStoragePath;
//   }

//   @override
//   Future<List<String>?> getExternalCachePaths() async {
//     return <String>[kExternalCachePath];
//   }

//   @override
//   Future<List<String>?> getExternalStoragePaths({
//     StorageDirectory? type,
//   }) async {
//     return <String>[kExternalStoragePath];
//   }

//   @override
//   Future<String?> getDownloadsPath() async {
//     return kDownloadsPath;
//   }
// }

// // TODO: Not testing for exception cases. Guess Exception handling is to be re-defined, so will handle those later.
// void main() {
//   // var locator;
//   final mockPathProvider = FakePathProviderPlatform();

//   setUpAll(() {
//     final GetIt locator = GetIt.instance;
//     locator.registerSingleton<Logger>(Logger());
//     WidgetsFlutterBinding.ensureInitialized();
//     PathProviderPlatform.instance = mockPathProvider;
//   });

//   group('createMnemonic()', () {
//     test('should return a list of 12 strings', () async {
//       final wallet = WalletSensitiveCreate();
//       final (mnemonic, mnError) = await wallet.createMnemonic();

//       expect(mnError, isNull);
//       expect(mnemonic?.length, equals(12));
//     });

//     test('should always return a list of 12 unique random strings', () async {
//       final wallet = WalletSensitiveCreate();
//       final results = <String>[];

//       for (var i = 0; i < 10; i++) {
//         final (mnemonic, mnError) = await wallet.createMnemonic();

//         expect(mnError, isNull);
//         expect(mnemonic?.length, equals(12));
//         final mnemonicString = mnemonic?.reduce((value, element) => value + element);
//         results.add(mnemonicString!);
//       }

//       // Ensure that each string in the results list is unique
//       for (var i = 0; i < results.length; i++) {
//         for (var j = i + 1; j < results.length; j++) {
//           expect(results[i], isNot(equals(results[j])));
//         }
//       }
//     });
//   });

//   group('getFingerprint()', () {
//     test('throw an error when empty string is sent as mnemonic', () async {
//       final wallet = WalletSensitiveCreate();
//       const mnemonic = '';
//       final (fingerprint, fpError) = await wallet.getFingerprint(mnemonic: mnemonic);

//       expect(fingerprint, isNull);
//       expect(
//         fpError.toString(),
//         Err('GenericException( mnemonic has an invalid word count: 0. Word count must be 12, 15, 18, 21, or 24 )')
//             .toString(),
//       );
//     });

//     test('throw an error when 11 word mnemonic is sent', () async {
//       final wallet = WalletSensitiveCreate();
//       const mnemonic = 'move decline opera album crisp nice ozone casual gate ozone cycle';
//       final passphrase = seed1Data.passphrases[0].passphrase;
//       final (fingerprint, fpError) =
//           await wallet.getFingerprint(mnemonic: mnemonic, passphrase: passphrase);

//       expect(fingerprint, isNull);
//       expect(
//         fpError.toString(),
//         Err(
//           'GenericException( mnemonic has an invalid word count: 11. Word count must be 12, 15, 18, 21, or 24 )',
//         ).toString(),
//       );
//     });

//     test('should return a fingerprint', () async {
//       final wallet = WalletSensitiveCreate();
//       final mnemonic = seed1Data.mnemonic;
//       final passphrase = seed1Data.passphrases[0].passphrase;
//       final (fingerprint, fpError) =
//           await wallet.getFingerprint(mnemonic: mnemonic, passphrase: passphrase);

//       expect(fpError, isNull);
//       expect(fingerprint, equals(seed1Fingerprint));
//     });
//   });

//   group('mnemonicSeed()', () {
//     // TODO: Error tests
//     test('should return a proper Seed object for a proper mnemonic', () async {
//       final wallet = WalletSensitiveCreate();
//       final mnemonic = seed1Data.mnemonic;
//       final (seed, seedError) = await wallet.mnemonicSeed(mnemonic, BBNetwork.Mainnet);

//       final Wallet testWallet = getTestWallet(BBNetwork.Mainnet, ScriptType.bip44, true);
//       expect(seedError, isNull);
//       expect(seed?.mnemonic, equals(mnemonic));
//       expect(seed?.mnemonicFingerprint, equals(testWallet.mnemonicFingerprint));
//       expect(seed?.passphrases, isEmpty);
//       expect(seed?.network, equals(BBNetwork.Mainnet));
//     });
//   });

//   // TODO: Handle exception cases
//   group('oneFromBIP39()', () {
//     final types = [ScriptType.bip44, ScriptType.bip49, ScriptType.bip84];

//     for (var i = 0; i < 3; i++) {
//       final type = types[i];

//       for (var j = 0; j < 2; j++) {
//         final hasImported = j == 0;

//         for (var k = 0; k < 2; k++) {
//           final network = k == 0 ? BBNetwork.Mainnet : BBNetwork.Testnet;

//           test(
//               'should return ${scriptTypeString(type)} ${network == BBNetwork.Mainnet ? 'Mainnet' : 'Testnet'} wallet for ${hasImported ? 'imported words' : 'new seed'}',
//               () async {
//             final create = WalletSensitiveCreate();
//             final mnemonic = seed1Data.mnemonic;
//             final passphrase = seed1Data.passphrases[0].passphrase;
//             final (mnemonicFingerprint, _) = await create.getFingerprint(
//               mnemonic: mnemonic,
//               passphrase: passphrase,
//             );
//             final seed = Seed(
//               mnemonic: mnemonic,
//               mnemonicFingerprint: mnemonicFingerprint!,
//               passphrases: [],
//               network: network,
//             );

//             final (wallet, walletError) =
//                 await create.oneFromBIP39(seed, passphrase, type, network, hasImported);

//             expect(walletError, isNull);

//             // print('wallet: $wallet');
//             final Wallet testWallet = getTestWallet(network, type, hasImported);

//             expect(wallet?.id, equals(testWallet.id));
//             expect(
//               wallet?.externalPublicDescriptor,
//               equals(
//                 testWallet.externalPublicDescriptor,
//               ),
//             );
//             expect(
//               wallet?.internalPublicDescriptor,
//               equals(
//                 testWallet.internalPublicDescriptor,
//               ),
//             );
//             expect(wallet?.mnemonicFingerprint, equals(seed1Fingerprint));
//             expect(wallet?.sourceFingerprint, equals(seed1Fingerprint));
//             expect(wallet?.network, equals(testWallet.network));
//             expect(wallet?.type, equals(testWallet.type));
//             expect(wallet?.scriptType, equals(testWallet.scriptType));
//             expect(wallet?.name, equals(testWallet.name));
//             expect(wallet?.path, testWallet.path);
//             expect(wallet?.balance, testWallet.balance);
//             expect(wallet?.fullBalance, testWallet.fullBalance);
//             expect(
//               wallet?.lastGeneratedAddress?.address,
//               equals(testWallet.lastGeneratedAddress?.address),
//             );
//             expect(
//               wallet?.lastGeneratedAddress?.index,
//               equals(testWallet.lastGeneratedAddress?.index),
//             );
//             expect(
//               wallet?.lastGeneratedAddress?.kind,
//               equals(testWallet.lastGeneratedAddress?.kind),
//             );
//             expect(
//               wallet?.lastGeneratedAddress?.state,
//               equals(testWallet.lastGeneratedAddress?.state),
//             );
//             expect(wallet?.lastGeneratedAddress?.label, testWallet.lastGeneratedAddress?.label);
//             expect(
//               wallet?.lastGeneratedAddress?.spentTxId,
//               testWallet.lastGeneratedAddress?.spentTxId,
//             );
//             expect(
//               wallet?.lastGeneratedAddress?.spendable,
//               testWallet.lastGeneratedAddress?.spendable,
//             );
//             expect(wallet?.lastGeneratedAddress?.saving, testWallet.lastGeneratedAddress?.saving);
//             expect(
//               wallet?.lastGeneratedAddress?.errSaving,
//               equals(testWallet.lastGeneratedAddress?.errSaving),
//             );
//             expect(
//               wallet?.lastGeneratedAddress?.highestPreviousBalance,
//               equals(testWallet.lastGeneratedAddress?.highestPreviousBalance),
//             );
//             expect(wallet?.lastGeneratedAddress?.utxos, testWallet.lastGeneratedAddress?.utxos);
//             expect(wallet?.myAddressBook, testWallet.myAddressBook);
//             expect(wallet?.externalAddressBook, testWallet.externalAddressBook);
//             expect(wallet?.transactions, testWallet.transactions);
//             expect(wallet?.unsignedTxs, testWallet.unsignedTxs);
//             expect(wallet?.backupTested, testWallet.backupTested);
//             expect(wallet?.lastBackupTested, testWallet.lastBackupTested);
//             expect(wallet?.hide, testWallet.hide);
//           });
//         }
//       }
//     }
//   });

//   // TODO: Handle exception cases
//   group('allFromBIP39()', () {
//     for (var j = 0; j < 2; j++) {
//       final hasImported = j == 0;

//       for (var k = 0; k < 2; k++) {
//         final network = k == 0 ? BBNetwork.Mainnet : BBNetwork.Testnet;

//         test(
//             'should return all (44, 49, 84) ${network == BBNetwork.Mainnet ? 'Mainnet' : 'Testnet'} wallet for ${hasImported ? 'imported words' : 'new seed'}',
//             () async {
//           final create = WalletSensitiveCreate();
//           final mnemonic = seed1Data.mnemonic;
//           final passphrase = seed1Data.passphrases[0].passphrase;

//           final (wallets, walletError) =
//               await create.allFromBIP39(mnemonic, passphrase, network, hasImported);

//           expect(walletError, isNull);

//           // print('wallet: $wallets');
//           final Wallet testWallet44 = getTestWallet(network, ScriptType.bip44, hasImported);
//           final Wallet testWallet49 = getTestWallet(network, ScriptType.bip49, hasImported);
//           final Wallet testWallet84 = getTestWallet(network, ScriptType.bip84, hasImported);
//           final List<Wallet> testWallets = [
//             testWallet44,
//             testWallet49,
//             testWallet84,
//           ];

//           for (var i = 0; i < 3; i++) {
//             expect(wallets?[i].id, equals(testWallets[i].id));
//             expect(
//               wallets?[i].externalPublicDescriptor,
//               equals(
//                 testWallets[i].externalPublicDescriptor,
//               ),
//             );
//             expect(
//               wallets?[i].internalPublicDescriptor,
//               equals(
//                 testWallets[i].internalPublicDescriptor,
//               ),
//             );
//             expect(wallets?[i].mnemonicFingerprint, equals(testWallets[i].mnemonicFingerprint));
//             expect(wallets?[i].sourceFingerprint, equals(testWallets[i].sourceFingerprint));
//             expect(wallets?[i].network, equals(testWallets[i].network));
//             expect(wallets?[i].type, equals(testWallets[i].type));
//             expect(wallets?[i].scriptType, equals(testWallets[i].scriptType));
//             expect(wallets?[i].name, equals(testWallets[i].name));
//             expect(wallets?[i].path, testWallets[i].path);
//             expect(wallets?[i].balance, testWallets[i].balance);
//             expect(wallets?[i].fullBalance, testWallets[i].fullBalance);
//             expect(
//               wallets?[i].lastGeneratedAddress?.address,
//               equals(testWallets[i].lastGeneratedAddress?.address),
//             );
//             expect(
//               wallets?[i].lastGeneratedAddress?.index,
//               equals(testWallets[i].lastGeneratedAddress?.index),
//             );
//             expect(
//               wallets?[i].lastGeneratedAddress?.kind,
//               equals(testWallets[i].lastGeneratedAddress?.kind),
//             );
//             expect(
//               wallets?[i].lastGeneratedAddress?.state,
//               equals(testWallets[i].lastGeneratedAddress?.state),
//             );
//             expect(
//               wallets?[i].lastGeneratedAddress?.label,
//               testWallets[i].lastGeneratedAddress?.label,
//             );
//             expect(
//               wallets?[i].lastGeneratedAddress?.spentTxId,
//               testWallets[i].lastGeneratedAddress?.spentTxId,
//             );
//             expect(
//               wallets?[i].lastGeneratedAddress?.spendable,
//               testWallets[i].lastGeneratedAddress?.spendable,
//             );
//             expect(
//               wallets?[i].lastGeneratedAddress?.saving,
//               testWallets[i].lastGeneratedAddress?.saving,
//             );
//             expect(
//               wallets?[i].lastGeneratedAddress?.errSaving,
//               equals(testWallets[i].lastGeneratedAddress?.errSaving),
//             );
//             expect(
//               wallets?[i].lastGeneratedAddress?.highestPreviousBalance,
//               equals(testWallets[i].lastGeneratedAddress?.highestPreviousBalance),
//             );
//             expect(
//               wallets?[i].lastGeneratedAddress?.utxos,
//               testWallets[i].lastGeneratedAddress?.utxos,
//             );
//             expect(wallets?[i].myAddressBook, testWallets[i].myAddressBook);
//             expect(wallets?[i].externalAddressBook, testWallets[i].externalAddressBook);
//             expect(wallets?[i].transactions, testWallets[i].transactions);
//             expect(wallets?[i].unsignedTxs, testWallets[i].unsignedTxs);
//             expect(wallets?[i].backupTested, testWallets[i].backupTested);
//             expect(wallets?[i].lastBackupTested, testWallets[i].lastBackupTested);
//             expect(wallets?[i].hide, testWallets[i].hide);
//           }
//         });
//       }
//     }
//   });
// }
