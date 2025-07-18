// import 'dart:convert';

// import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';
// import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_encrypted_vault_from_backup_key_usecase.dart';
// import 'package:bb_mobile/core/tor/domain/repositories/tor_repository.dart';
// import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
// import 'package:bb_mobile/features/backup_wallet/domain/usecases/create_encrypted_vault_usecase.dart';
// import 'package:bb_mobile/features/key_server/domain/usecases/check_key_server_connection_usecase.dart';
// import 'package:bb_mobile/features/key_server/domain/usecases/derive_backup_key_from_default_wallet_usecase.dart';
// import 'package:bb_mobile/features/key_server/domain/usecases/restore_backup_key_from_password_usecase.dart';
// import 'package:bb_mobile/features/key_server/domain/usecases/store_backup_key_into_server_usecase.dart';
// import 'package:bb_mobile/locator.dart';
// import 'package:bip85/bip85.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:hex/hex.dart';
// import 'package:lwk/lwk.dart';
// import 'package:test/test.dart';

// void main() {
//   late WalletRepository walletRepository;
//   late TorRepository torRepository;
//   late CheckKeyServerConnectionUsecase checkKeyServerConnection;
//   late CreateEncryptedVaultUsecase createEncryptedVault;
//   late DeriveBackupKeyFromDefaultWalletUsecase deriveBackupKey;
//   late StoreBackupKeyIntoServerUsecase storeBackupKey;
//   late RestoreBackupKeyFromPasswordUsecase restoreBackupKey;
//   late DeriveBackupKeyFromDefaultWalletUsecase deriveBackupKeyFromDefaultWallet;
//   late RestoreEncryptedVaultFromBackupKeyUsecase restoreEncryptedVault;

//   Future<void> waitForTor({int maxAttempts = 3}) async {
//     debugPrint('Starting TOR initialization...');
//     if (!await torRepository.isTorReady) {
//       await torRepository.start();
//       var attempts = 0;
//       while (!await torRepository.isTorReady && attempts < maxAttempts) {
//         await Future.delayed(const Duration(seconds: 1));
//         attempts++;
//         if (attempts % 10 == 0) {
//           debugPrint('Waiting for TOR... Attempt $attempts');
//         }
//       }
//       if (!await torRepository.isTorReady) {
//         throw Exception(
//           'TOR initialization timeout after $maxAttempts seconds',
//         );
//       }
//     }
//     debugPrint('TOR initialization complete');
//   }

//   const dummyBackupFile =
//       "7b22637265617465645f6174223a313734333032353338333534392c226964223a2266373631643035616261363362613164626633366637356532666437373361366133333366636535386337633639336235383034313638646564643138313235222c2263697068657274657874223a226444702f6873505665444b545a5162432b356f416371557a574e394f664e3835585276336f703069466874434b54467856445748387550666c667852525263463454766b70345663342f4d4c4577744549344b35464b694e3970416931676e6439386543594875653346386a6772686572736c4a764c523547396154724357736675654f685274436130597272526349622f5a4137546772575671445175763637643555394f506730487653783530447364644b48782f46514a5a6141576e435a517847553277594253697758335959416665322f5265514c4b7a614747474f3249392b3463506272446a594b5450783235476e45476465783669356c625a72414e2b4c5a4c3462324c64376138756374384d5a6d6741773253504c714673306e3362644939504a4c372b4c7456634e31664e754755316745446a3338786d576658416458707532666d7179575a78784f483133664e42452b37706375647a7771393659466a727775366f46774e6a545558322f6741332f456e61454f7a2f532b4d393933447653632f55694f34686d6b6567744c4c6e534b4e50435242757a38704b45483052454c3372777531553251694b756e6563667264796b304a4234304432544b3064546e584a5773554530726b337436454566506149464563306e4e307234506130354b3642714a3576386b6574586f35444747504d7063536773677a4b325141673966486b4f70614e77424a6252666a32467932716673513362336931497172347766356e2f364b4f47336349387944796950564f4f7672637041746c556e767436654c6b6c41633674776a6d6a5231422f46714f655855644c747a675a77356a774e694f4362476e6d3076462b526d4f5a714e7a6456584749374e5672742b665a7a35543475324d4c4b38445a7178422f467055323156524d5945683752773847704737656e35495339336237637a504a76744c456f5a563557495a716c4f585358456577416747444c4f4a552f356c65584972376a6d726b3338556e2b786c65764f515a4b4a56736171776c613675396d574d3956625454734357554637434855536458456649714f4d49794b345562726e336465504344684a696641594f325576676b53593635642b41784b36435331773530736252796651623535396478392b36754c36616265726b437949366932313074702f6d777168416747694c306e2f3741327231412b447a6f594655746f647a78674f5666472f4d6c4964484e2f7958474e6d3255384147614733574a4d70306e504865392f4b6c5a4366516b4c474570485a4e634f4b78722f445856553063326e4251722b6666472f4e63664d436a462b69452b436f43344246615568737774484f37323266444e314a6842596876544947746745346f576a6c583667316438654b596139346b59414373424374364754776556464a61665033657a4e56657470504b72494a72346e3856796478555448335a6330777248627954784b4e6a33734a354b6776634d714d70564138454b5477414a795452624d494775624f5471654f49324a44594f4e63456e587a434a5a71736a754a456a566b5a2f69527576544c3743576138784f7a50646232787435554c664c494c36676c683537572b71397159363139477355424c526a4c45352b49636e36644e564f323842314949644d3275307939465a687a45432f55564473626754592f4e767875594d6b744a5371456a70446363634367362f62766a6c4e36366159346251715a6939776e2b5a43706e326c52374a636c76433544662f326d76306a2b78746c5a4f47796c32624c5932337968365a65414a3537764a614d676d636173785659333947496735436150532f4c514c654f424b7335442f736449747964594a6a64773d3d222c2273616c74223a223264663135353332653062313665343062653163323662353464633332333462222c2270617468223a226d2f31363038272f30272f31333434313536303832227d";
//   const dummyBackupKey =
//       "ae56a4c6da2251de94df375d4e78bb4b483c6d31129042b1c3df62476a74728c";

//   setUpAll(() async {
//     try {
//       debugPrint('Starting test setup...');
//       await dotenv.load(isOptional: true);
//       await LibBip85.init();
//       await LibLwk.init();
//       await AppLocator.setup();

//       torRepository = locator<TorRepository>();
//       walletRepository = locator<WalletRepository>();
//       locator<RecoverBullRepository>();
//       checkKeyServerConnection = locator<CheckKeyServerConnectionUsecase>();
//       createEncryptedVault = locator<CreateEncryptedVaultUsecase>();
//       deriveBackupKey = locator<DeriveBackupKeyFromDefaultWalletUsecase>();
//       storeBackupKey = locator<StoreBackupKeyIntoServerUsecase>();
//       restoreBackupKey = locator<RestoreBackupKeyFromPasswordUsecase>();
//       restoreEncryptedVault =
//           locator<RestoreEncryptedVaultFromBackupKeyUsecase>();
//       deriveBackupKeyFromDefaultWallet =
//           locator<DeriveBackupKeyFromDefaultWalletUsecase>();
//       debugPrint('Creating default wallets...');

//       // await createDefaultWallets
//       //     .execute(mnemonicWords: dummyMnemonic.split(' '))
//       //     .timeout(
//       //       const Duration(seconds: 2),
//       //       onTimeout: () =>
//       //           throw Exception('Default wallets creation timeout'),
//       //     );
//       debugPrint('Basic initialization complete, starting TOR...');
//       await waitForTor();

//       debugPrint('Setup complete');
//     } catch (e) {
//       debugPrint('Setup failed: $e');
//       rethrow;
//     }
//   });

//   test('Complete RecoverBull Flow Test', () async {
//     const password = 'SecurePassw0rd!';

//     debugPrint('Starting recovery flow test...');
//     await waitForTor();
//     expect(await torRepository.isTorReady, true);
//     await Future.delayed(const Duration(seconds: 2));

//     // First attempt restore with dummy data
//     debugPrint('Attempting restore with dummy data...');
//     try {
//       await restoreEncryptedVault.execute(
//         backupFile: utf8.decode(HEX.decode(dummyBackupFile)),
//         backupKey: dummyBackupKey,
//       );
//     } catch (e) {
//       debugPrint('Initial restore attempt completed: $e');
//     }
//     final derivedBackupKey = await deriveBackupKeyFromDefaultWallet.execute(
//       backupFile: utf8.decode(HEX.decode(dummyBackupFile)),
//     );
//     expect(derivedBackupKey, equals(dummyBackupKey));
//     debugPrint('Backup key restored successfully');

//     // Create new backup and compare
//     debugPrint('Creating new backup for comparison...');
//     final backupFile = await createEncryptedVault.execute().timeout(
//       const Duration(seconds: 2),
//       onTimeout: () => throw Exception('Backup creation timeout'),
//     );
//     debugPrint('Checking server connection...');
//     await checkKeyServerConnection.execute().timeout(
//       const Duration(seconds: 10),
//       onTimeout: () => throw Exception('Server connection timeout'),
//     );
//     // Derive and compare backup keys
//     debugPrint('Deriving and comparing backup keys...');
//     final backupKey = await deriveBackupKey.execute(backupFile: backupFile);

//     // Test recovery process
//     debugPrint('Testing recovery process...');
//     await storeBackupKey.execute(
//       password: password,
//       backupFile: backupFile,
//       backupKey: backupKey,
//     );

//     final restoredBackupKey = await restoreBackupKey.execute(
//       backupFile: backupFile,
//       password: password,
//     );
//     expect(restoredBackupKey, equals(backupKey));

//     // Final restore attempt
//     // debugPrint('Attempting final restore...');
//     try {
//       await restoreEncryptedVault.execute(
//         backupFile: backupFile,
//         backupKey: restoredBackupKey,
//       );
//     } catch (e) {
//       if (e.toString().contains('default wallet already exists')) {
//         debugPrint('Default wallet exists - Test successful');
//       } else {
//         rethrow;
//       }
//     }

//     // Verify final state
//     debugPrint('Verifying wallet state...');
//     final wallets = await walletRepository.getWallets(sync: true);
//     expect(wallets, isNotEmpty);
//     debugPrint('Test completed successfully');
//   }, timeout: const Timeout(Duration(minutes: 5)));

//   tearDownAll(() async {
//     try {
//       await torRepository.stop();
//     } catch (e) {
//       debugPrint('Teardown error: $e');
//     }
//   });
// }
