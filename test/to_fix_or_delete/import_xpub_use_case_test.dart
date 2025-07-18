// import 'package:bb_mobile/_core/domain/entities/settings.dart';
// import 'package:bb_mobile/_core/domain/entities/wallet.dart';
// import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
// import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
// import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';
// import 'package:bb_mobile/import_watch_only_wallet/domain/usecases/import_xpub_use_case.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:mocktail/mocktail.dart';

// class MockSettingsRepository extends Mock implements SettingsRepository {}

// class MockWalletManagerService extends Mock implements WalletManagerService {}

// void main() {
//   late MockSettingsRepository mockSettingsRepository;
//   late MockWalletManagerService mockWalletManagerService;
//   late ImportXpubUsecase importXpubUsecase;

//   setUp(() {
//     mockSettingsRepository = MockSettingsRepository();
//     mockWalletManagerService = MockWalletManagerService();
//     importXpubUsecase = ImportXpubUsecase(
//       settingsRepository: mockSettingsRepository,
//       walletManagerService: mockWalletManagerService,
//     );
//   });

//   group('ImportXpubUsecase', () {
//     const testXpub = 'xpub6CUGRU...'; // Example xpub
//     const testScriptType = ScriptType.bip84;
//     const testLabel = 'Test Wallet';
//     const testNetworkMainnet = Network.bitcoinMainnet;
//     const testNetworkTestnet = Network.bitcoinTestnet;

//     final testWallet = Wallet(
//       id: 'wallet-1',
//       label: testLabel,
//       network: testNetworkMainnet,
//       xpubFingerprint: 'abcd1234',
//       scriptType: testScriptType,
//       xpub: testXpub,
//       externalPublicDescriptor: 'wpkh([abcd1234]xpub...)',
//       internalPublicDescriptor: 'wpkh([abcd1234]xpub.../1/*)',
//       source: WalletSource.xpub,
//       balanceSat: BigInt.zero,
//     );

//     test('should import a watch-only wallet on mainnet', () async {
//       when(() => mockSettingsRepository.getEnvironment())
//           .thenAnswer((_) async => Environment.mainnet);

//       when(
//         () => mockWalletManagerService.importWatchOnlyWallet(
//           xpub: testXpub,
//           network: testNetworkMainnet,
//           scriptType: testScriptType,
//           label: testLabel,
//         ),
//       ).thenAnswer((_) async => testWallet);

//       final result = await importXpubUsecase.execute(
//         xpub: testXpub,
//         scriptType: testScriptType,
//         label: testLabel,
//       );

//       expect(result, equals(testWallet));

//       verify(() => mockSettingsRepository.getEnvironment()).called(1);
//       verify(
//         () => mockWalletManagerService.importWatchOnlyWallet(
//           xpub: testXpub,
//           network: testNetworkMainnet,
//           scriptType: testScriptType,
//           label: testLabel,
//         ),
//       ).called(1);
//       verifyNoMoreInteractions(mockSettingsRepository);
//       verifyNoMoreInteractions(mockWalletManagerService);
//     });

//     test('should import a watch-only wallet on testnet', () async {
//       when(() => mockSettingsRepository.getEnvironment())
//           .thenAnswer((_) async => Environment.testnet);

//       final testWalletTestnet =
//           testWallet.copyWith(network: testNetworkTestnet);

//       when(
//         () => mockWalletManagerService.importWatchOnlyWallet(
//           xpub: testXpub,
//           network: testNetworkTestnet,
//           scriptType: testScriptType,
//           label: testLabel,
//         ),
//       ).thenAnswer((_) async => testWalletTestnet);

//       final result = await importXpubUsecase.execute(
//         xpub: testXpub,
//         scriptType: testScriptType,
//         label: testLabel,
//       );

//       expect(result, equals(testWalletTestnet));

//       verify(() => mockSettingsRepository.getEnvironment()).called(1);
//       verify(
//         () => mockWalletManagerService.importWatchOnlyWallet(
//           xpub: testXpub,
//           network: testNetworkTestnet,
//           scriptType: testScriptType,
//           label: testLabel,
//         ),
//       ).called(1);
//       verifyNoMoreInteractions(mockSettingsRepository);
//       verifyNoMoreInteractions(mockWalletManagerService);
//     });

//     test('should throw an exception when import fails', () async {
//       when(() => mockSettingsRepository.getEnvironment())
//           .thenAnswer((_) async => Environment.mainnet);

//       when(
//         () => mockWalletManagerService.importWatchOnlyWallet(
//           xpub: testXpub,
//           network: testNetworkMainnet,
//           scriptType: testScriptType,
//           label: testLabel,
//         ),
//       ).thenThrow(Exception('Import failed'));

//       await expectLater(
//         () async => await importXpubUsecase.execute(
//           xpub: testXpub,
//           scriptType: testScriptType,
//           label: testLabel,
//         ),
//         throwsA(isA<ImportXpubException>()),
//       );

//       verify(() => mockSettingsRepository.getEnvironment()).called(1);
//       verify(
//         () => mockWalletManagerService.importWatchOnlyWallet(
//           xpub: testXpub,
//           network: testNetworkMainnet,
//           scriptType: testScriptType,
//           label: testLabel,
//         ),
//       ).called(1);
//     });
//   });
// }
