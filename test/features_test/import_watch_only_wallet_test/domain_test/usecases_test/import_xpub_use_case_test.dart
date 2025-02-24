import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/core/domain/services/wallet_metadata_derivation_service.dart';
import 'package:bb_mobile/core/domain/services/wallet_repository_manager.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/usecases/import_xpub_use_case.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockWalletMetadataDerivationService extends Mock
    implements WalletMetadataDerivationService {}

class MockWalletMetadataRepository extends Mock
    implements WalletMetadataRepository {}

class MockWalletRepositoryManager extends Mock
    implements WalletRepositoryManager {}

void main() {
  late ImportXpubUseCase useCase;
  late MockSettingsRepository mockSettingsRepository;
  late MockWalletMetadataDerivationService mockWalletMetadataDerivationService;
  late MockWalletMetadataRepository mockWalletMetadataRepository;
  late MockWalletRepositoryManager mockWalletRepositoryManager;

  setUp(() {
    mockSettingsRepository = MockSettingsRepository();
    mockWalletMetadataDerivationService = MockWalletMetadataDerivationService();
    mockWalletMetadataRepository = MockWalletMetadataRepository();
    mockWalletRepositoryManager = MockWalletRepositoryManager();

    useCase = ImportXpubUseCase(
      settingsRepository: mockSettingsRepository,
      walletMetadataDerivationService: mockWalletMetadataDerivationService,
      walletMetadataRepository: mockWalletMetadataRepository,
      walletRepositoryManager: mockWalletRepositoryManager,
    );
  });

  final testXpub = 'xpub1234567890';
  final testScriptType = ScriptType.bip84;
  final testLabel = 'Test Wallet';
  final testMetadata = WalletMetadata(
    masterFingerprint: '',
    xpubFingerprint: 'fingerprint1234',
    network: Network.bitcoinMainnet,
    scriptType: testScriptType,
    xpub: testXpub,
    externalPublicDescriptor: 'desc-external',
    internalPublicDescriptor: 'desc-internal',
    source: WalletSource.xpub,
    isDefault: false,
    label: testLabel,
  );

  group('ImportXpubUseCase - execute', () {
    test('imports xpub for mainnet and registers wallet', () async {
      // Arrange: Set up mock responses
      when(() => mockSettingsRepository.getEnvironment())
          .thenAnswer((_) async => Environment.mainnet);

      when(() => mockWalletMetadataDerivationService.fromXpub(
            xpub: testXpub,
            network: Network.bitcoinMainnet,
            scriptType: testScriptType,
            label: testLabel,
          )).thenAnswer((_) async => testMetadata);

      when(() => mockWalletMetadataRepository.storeWalletMetadata(testMetadata))
          .thenAnswer((_) async {});

      when(() => mockWalletRepositoryManager.registerWallet(testMetadata))
          .thenAnswer((_) async {});

      // Act
      await useCase.execute(
        xpub: testXpub,
        scriptType: testScriptType,
        label: testLabel,
      );

      // Assert
      verify(() => mockSettingsRepository.getEnvironment()).called(1);
      verify(() => mockWalletMetadataDerivationService.fromXpub(
            xpub: testXpub,
            network: Network.bitcoinMainnet,
            scriptType: testScriptType,
            label: testLabel,
          )).called(1);
      verify(() =>
              mockWalletMetadataRepository.storeWalletMetadata(testMetadata))
          .called(1);
      verify(() => mockWalletRepositoryManager.registerWallet(testMetadata))
          .called(1);
    });

    test('imports xpub for testnet and registers wallet', () async {
      // Arrange: Set up mock responses
      when(() => mockSettingsRepository.getEnvironment())
          .thenAnswer((_) async => Environment.testnet);

      final testMetadataTestnet =
          testMetadata.copyWith(network: Network.bitcoinTestnet);

      when(() => mockWalletMetadataDerivationService.fromXpub(
            xpub: testXpub,
            network: Network.bitcoinTestnet,
            scriptType: testScriptType,
            label: testLabel,
          )).thenAnswer((_) async => testMetadataTestnet);

      when(() => mockWalletMetadataRepository
          .storeWalletMetadata(testMetadataTestnet)).thenAnswer((_) async {});

      when(() =>
              mockWalletRepositoryManager.registerWallet(testMetadataTestnet))
          .thenAnswer((_) async {});

      // Act
      await useCase.execute(
        xpub: testXpub,
        scriptType: testScriptType,
        label: testLabel,
      );

      // Assert
      verify(() => mockSettingsRepository.getEnvironment()).called(1);
      verify(() => mockWalletMetadataDerivationService.fromXpub(
            xpub: testXpub,
            network: Network.bitcoinTestnet,
            scriptType: testScriptType,
            label: testLabel,
          )).called(1);
      verify(() => mockWalletMetadataRepository
          .storeWalletMetadata(testMetadataTestnet)).called(1);
      verify(() =>
              mockWalletRepositoryManager.registerWallet(testMetadataTestnet))
          .called(1);
    });
  });
}
