// import 'package:bb_mobile/_model/wallet.dart';
// 
// import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
// import 'package:bb_mobile/_pkg/result.dart';
// import 'package:bb_mobile/_pkg/secured_storage.dart';
// import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
// import 'package:bb_mobile/wallet/bloc/wallet_cubit.dart';
// import 'package:bb_mobile/wallet/bloc/state.dart';
// import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
// import 'package:bloc_test/bloc_test.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_animate/flutter_animate.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:mocktail/mocktail.dart';

// import '../../maintainance/test/__test_utils/path_provider.dart';
// import '../../maintainance/test/__test_utils/wallets.dart';

// void main() {
//   WidgetsFlutterBinding.ensureInitialized();

//   late WalletCubit walletCubit;

//   setUpAll(() async {
//     PathProviderPlatform.instance = FakePathProvider();

//     final settingsCubit = SettingsCubit(
//       storage: MockSecureStorage(),
//       bbAPI: BullBitcoinAPI(),
//     );

//     walletCubit = WalletCubit(
//       walletStorage: MockWalletStorage(),
//       saveDir: w1.fingerprint,
//       settingsCubit: settingsCubit,
//       walletRead: 
//     );
//   });

//   testWidgets('Load BDK Wallet', (t) async {
//     await Future.delayed(300.milliseconds);
//     expect(walletCubit.state.bdkWallet, isNotNull);
//   });

//   testWidgets('failing test example', (tester) async {
//     try {
//       final mne = await bdk.Mnemonic.create(bdk.WordCount.Words12);
//       print(mne);
//     } catch (e) {
//       print(e);
//     }
//   });

//   blocTest<WalletCubit, WalletState>(
//     'description',
//     build: () => walletCubit,
//     // act: (cubit) => cubit.loadWallet(w1.fingerprint),
//     expect: () => [
//       const WalletState(
//         loadingWallet: true,
//         errLoadingWallet: '',
//       ),
//       const WalletState(
//         loadingWallet: true,
//         wallet: w1,
//       ),
//     ],
//   );
// }

// class MockWalletStorage extends Mock implements WalletStorage {
//   @override
//   Future<Result<Wallet>> getWalletDetails(
//     String fingerprint, {
//     bool removeSensitive = false,
//   }) async {
//     return Result(value: w1);
//   }
// }

// class MockSecureStorage extends Mock implements SecureStorage {
//   @override
//   Future<Result<String>> getValue(
//     StorageKeys key,
//   ) async {
//     return Result(error: 'Storage Empty');
//   }

//   @override
//   Future<Result<void>> saveValue({
//     required StorageKeys key,
//     required String value,
//   }) async {
//     return Result();
//   }
// }
