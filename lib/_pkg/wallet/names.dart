// import 'package:bb_mobile/_pkg/error.dart';
// import 'package:bb_mobile/_pkg/storage/hive.dart';
// import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';

// class WalletNames {
//   Future<(List<String>?, Err?)> getAllNames({
//     required HiveStorage hiveStore,
//   }) async {
//     try {
//       // final name = wallet.defaultNameString();
//       final (wallets, err) = await WalletsStorageRepository().readAllWallets(
//         hiveStore: hiveStore,
//       );
//       if (err != null) {
//         return (null, Err(err.toString()));
//       }
//       final walletNames = wallets!.map((wallet) => wallet.name!).toList();
//       return (walletNames, null);
//     } on Exception catch (e) {
//       return (
//         null,
//         Err(
//           e.message,
//           title: 'Error occurred while getting wallet names',
//           solution: 'Please try again.',
//         )
//       );
//     }
//   }
// }
