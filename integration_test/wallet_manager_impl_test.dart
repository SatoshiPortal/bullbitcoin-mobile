import 'dart:io';

import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager.dart';
import 'package:bb_mobile/_core/domain/services/wallet_metadata_derivator.dart';
import 'package:lwk/lwk.dart' as lwk;
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:test/test.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockSeedRepository extends Mock implements SeedRepository {}

class MockWalletMetadataRepository extends Mock
    implements WalletMetadataRepository {}

class MockWalletMetadataDerivator extends Mock
    implements WalletMetadataDerivator {}

void main() {
  late WalletManagerImpl manager;
  late MockSettingsRepository settingsRepository;
  late MockSeedRepository seedRepository;
  late MockWalletMetadataRepository walletMetadataRepository;
  late MockWalletMetadataDerivator walletMetadataDerivator;
  late Directory appDirectory;

  setUp(() async {
    settingsRepository = MockSettingsRepository();
    seedRepository = MockSeedRepository();
    walletMetadataRepository = MockWalletMetadataRepository();
    walletMetadataDerivator = MockWalletMetadataDerivator();

    manager = WalletManagerImpl(
      walletMetadataDerivator: walletMetadataDerivator,
      seedRepository: seedRepository,
      settingsRepository: settingsRepository,
      walletMetadataRepository: walletMetadataRepository,
    );

    await lwk.LibLwk.init();
    appDirectory = await getApplicationDocumentsDirectory();
  });

  const testBitcoinMetadata = WalletMetadata(
    masterFingerprint: '73c5da0a',
    xpubFingerprint: 'fd13aac9',
    network: Network.bitcoinMainnet,
    scriptType: ScriptType.bip84,
    xpub:
        'zpub6rFR7y4Q2AijBEqTUquhVz398htDFrtymD9xYYfG1m4wAcvPhXNfE3EfH1r1ADqtfSdVCToUG868RvUUkgDKf31mGDtKsAYz2oz2AGutZYs',
    externalPublicDescriptor:
        "wpkh([73c5da0a/84'/0'/0']xpub6CatWdiZiodmUeTDp8LT5or8nmbKNcuyvz7WyksVFkKB4RHwCD3XyuvPEbvqAQY3rAPshWcMLoP2fMFMKHPJ4ZeZXYVUhLv1VMrjPC7PW6V/0/*)#wc3n3van",
    internalPublicDescriptor:
        "wpkh([73c5da0a/84'/0'/0']xpub6CatWdiZiodmUeTDp8LT5or8nmbKNcuyvz7WyksVFkKB4RHwCD3XyuvPEbvqAQY3rAPshWcMLoP2fMFMKHPJ4ZeZXYVUhLv1VMrjPC7PW6V/1/*)#lv5jvedt",
    source: WalletSource.mnemonic,
    isDefault: true,
    label: 'Bitcoin Wallet',
  );

  const testLiquidMetadata = WalletMetadata(
    masterFingerprint: '73c5da0a',
    xpubFingerprint: '5a00fb4f',
    network: Network.liquidMainnet,
    scriptType: ScriptType.bip84,
    xpub:
        'zpub6r5nbp27YaffuknV3Egk4fLJiKWKTqp6CmVGZHLukWsvUfqAiwyuziKxED9juLgQQLB16xdcXYEmycB4Ws1v44W4rrF1mHPmxrG8ZBQ81RP',
    externalPublicDescriptor:
        'ct(slip77(9c8e4f05c7711a98c838be228bcb84924d4570ca53f35fa1c793e58841d47023),elwpkh([73c5da0a/84h/1776h/0h]xpub6CRFzUgHFDaiDAQFNX7VeV9JNPDRabq6NYSpzVZ8zW8ANUCiDdenkb1gBoEZuXNZb3wPc1SVcDXgD2ww5UBtTb8s8ArAbTkoRQ8qn34KgcY/<0;1>/*))#y8jljyxl',
    internalPublicDescriptor:
        'ct(slip77(9c8e4f05c7711a98c838be228bcb84924d4570ca53f35fa1c793e58841d47023),elwpkh([73c5da0a/84h/1776h/0h]xpub6CRFzUgHFDaiDAQFNX7VeV9JNPDRabq6NYSpzVZ8zW8ANUCiDdenkb1gBoEZuXNZb3wPc1SVcDXgD2ww5UBtTb8s8ArAbTkoRQ8qn34KgcY/<0;1>/*))#y8jljyxl',
    source: WalletSource.mnemonic,
    isDefault: true,
    label: 'Liquid Wallet',
  );

  /* TODO: Fix WalletManager Integration Tests after refactoring
  group('WalletManager Integration Tests', () {
    
    test('registers and retrieves a Bitcoin wallet', () async {
      await manager.registerWallet(testBitcoinMetadata);

      final repository = manager.getRepository(testBitcoinMetadata.id);

      expect(repository, isA<BdkWalletRepositoryImpl>());
      expect(repository?.id, testBitcoinMetadata.id);
    });

    test('registers and retrieves a Liquid wallet', () async {
      await manager.registerWallet(testLiquidMetadata);

      final repository = manager.getRepository(testLiquidMetadata.id);

      expect(repository, isA<LwkWalletRepositoryImpl>());
      expect(repository?.id, testLiquidMetadata.id);

      // Verify LWK Wallet Creation
      final walletPath = '${appDirectory.path}/${testLiquidMetadata.id}';
      expect(Directory(walletPath).existsSync(), isTrue);
    });

    test('retrieves all registered wallets', () async {
      await manager.registerWallet(testBitcoinMetadata);
      await manager.registerWallet(testLiquidMetadata);

      final repositories = manager.getRepositories();

      expect(repositories.length, 2);
    });

    test('retrieves only mainnet wallets', () async {
      await manager.registerWallet(testBitcoinMetadata);
      await manager.registerWallet(testLiquidMetadata);

      final mainnetWallets =
          manager.getRepositories(environment: Environment.mainnet);

      expect(mainnetWallets.length, 2);
      expect(mainnetWallets.first.network.isMainnet, isTrue);
    });

    test('retrieves only testnet wallets', () async {
      final testTestnetMetadata =
          testLiquidMetadata.copyWith(network: Network.liquidTestnet);
      await manager.registerWallet(testTestnetMetadata);

      final testnetWallets =
          manager.getRepositories(environment: Environment.testnet);

      expect(testnetWallets.length, 1);
      expect(testnetWallets.first.network.isTestnet, isTrue);
    });
  });*/

  tearDown(() async {
    // Clean up the created wallet directories after each test
    final testWalletPaths = [
      '${appDirectory.path}/${testBitcoinMetadata.id}',
      '${appDirectory.path}/${testLiquidMetadata.id}',
    ];
    for (final path in testWalletPaths) {
      final dir = Directory(path);
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    }
  });
}
