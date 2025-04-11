// import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
// import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
// import 'package:bb_mobile/core/wallet/data/repositories/wallet_metadata_repository_impl.dart';
// import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';
// import 'package:mocktail/mocktail.dart';
// import 'package:test/test.dart';

// class MockWalletMetadataSource extends Mock
//     implements WalletMetadataDatasource {}

// void main() {
//   late MockWalletMetadataSource mockDatasource;
//   late WalletMetadataRepositoryImpl repository;

//   setUp(() {
//     mockDatasource = MockWalletMetadataSource();
//     repository = WalletMetadataRepositoryImpl(source: mockDatasource);
//   });

//   const testMetadata = WalletMetadata(
//     id: 'fd13aac9:bitcoin:mainnet',
//     masterFingerprint: '73c5da0a',
//     xpubFingerprint: 'fd13aac9',
//     network: Network.bitcoinMainnet,
//     scriptType: ScriptType.bip84,
//     xpub:
//         'zpub6rFR7y4Q2AijBEqTUquhVz398htDFrtymD9xYYfG1m4wAcvPhXNfE3EfH1r1ADqtfSdVCToUG868RvUUkgDKf31mGDtKsAYz2oz2AGutZYs',
//     externalPublicDescriptor:
//         "wpkh([73c5da0a/84'/0'/0']xpub6CatWdiZiodmUeTDp8LT5or8nmbKNcuyvz7WyksVFkKB4RHwCD3XyuvPEbvqAQY3rAPshWcMLoP2fMFMKHPJ4ZeZXYVUhLv1VMrjPC7PW6V/0/*)#wc3n3van",
//     internalPublicDescriptor:
//         "wpkh([73c5da0a/84'/0'/0']xpub6CatWdiZiodmUeTDp8LT5or8nmbKNcuyvz7WyksVFkKB4RHwCD3XyuvPEbvqAQY3rAPshWcMLoP2fMFMKHPJ4ZeZXYVUhLv1VMrjPC7PW6V/1/*)#lv5jvedt",
//     source: WalletSource.mnemonic,
//     isDefault: true,
//   );

//   group('HiveWalletMetadataRepositoryImpl - storeWalletMetadata', () {
//     test('stores wallet metadata correctly', () async {
//       when(
//         () => mockDatasource.store(
//           WalletMetadataModel.fromEntity(testMetadata),
//         ),
//       ).thenAnswer((_) async {});

//       await repository.store(testMetadata);

//       verify(
//         () => mockDatasource.store(
//           WalletMetadataModel.fromEntity(testMetadata),
//         ),
//       ).called(1);
//     });
//   });

//   group('HiveWalletMetadataRepositoryImpl - getWalletMetadata', () {
//     test('returns wallet metadata if found', () async {
//       when(() => mockDatasource.get(testMetadata.id)).thenAnswer(
//         (_) async => WalletMetadataModel.fromEntity(testMetadata),
//       );

//       final result = await repository.get(testMetadata.id);

//       expect(result, equals(testMetadata));
//     });

//     test('returns null if wallet metadata is not found', () async {
//       when(() => mockDatasource.get('unknown-id'))
//           .thenAnswer((_) async => null);

//       final result = await repository.get('unknown-id');

//       expect(result, isNull);
//     });
//   });

//   group('HiveWalletMetadataRepositoryImpl - getAllWalletsMetadata', () {
//     test('returns a list of all wallet metadata', () async {
//       when(() => mockDatasource.getAll()).thenAnswer(
//         (_) async => [
//           WalletMetadataModel.fromEntity(testMetadata),
//         ],
//       );

//       final result = await repository.getAll();

//       expect(result, contains(testMetadata));
//       expect(result.length, equals(1));
//     });

//     test('returns an empty list if no wallets exist', () async {
//       when(() => mockDatasource.getAll()).thenAnswer((_) async => []);

//       final result = await repository.getAll();

//       expect(result, isEmpty);
//     });
//   });

//   group('HiveWalletMetadataRepositoryImpl - deleteWalletMetadata', () {
//     test('deletes wallet metadata correctly', () async {
//       when(() => mockDatasource.delete(testMetadata.id))
//           .thenAnswer((_) async {});

//       await repository.delete(testMetadata.id);

//       verify(() => mockDatasource.delete(testMetadata.id)).called(1);
//     });
//   });
// }
