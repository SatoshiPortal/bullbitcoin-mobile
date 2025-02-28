import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/entities/wallet.dart';
import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/domain/services/wallet_manager.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/usecases/import_xpub_use_case.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockWalletManager extends Mock implements WalletManager {}

void main() {
  late ImportXpubUseCase useCase;
  late MockSettingsRepository mockSettingsRepository;
  late MockWalletManager mockWalletManager;

  setUp(() {
    mockSettingsRepository = MockSettingsRepository();
    mockWalletManager = MockWalletManager();

    useCase = ImportXpubUseCase(
      settingsRepository: mockSettingsRepository,
      walletManager: mockWalletManager,
    );
  });

  const testXpub = 'xpub1234567890';
  const testScriptType = ScriptType.bip84;
  const testLabel = 'Test Wallet';

  group('ImportXpubUseCase - execute', () {
    test('imports xpub for mainnet', () async {
      final result = Wallet(
        id: 'id1234',
        name: 'Test Wallet',
        network: Network.bitcoinMainnet,
        balanceSat: BigInt.zero,
        isDefault: false,
      );

      // Arrange: Set up mock responses
      when(() => mockSettingsRepository.getEnvironment())
          .thenAnswer((_) async => Environment.mainnet);

      when(() => mockWalletManager.importWatchOnlyWallet(
            xpub: testXpub,
            network: Network.bitcoinMainnet,
            scriptType: testScriptType,
            label: testLabel,
          )).thenAnswer((_) async {
        return result;
      });

      // Act
      final wallet = await useCase.execute(
        xpub: testXpub,
        scriptType: testScriptType,
        label: testLabel,
      );

      // Assert
      expect(wallet, result);
      verify(() => mockSettingsRepository.getEnvironment()).called(1);
      verify(
        () => mockWalletManager.importWatchOnlyWallet(
          xpub: testXpub,
          network: Network.bitcoinMainnet,
          scriptType: testScriptType,
          label: testLabel,
        ),
      ).called(1);
    });

    test('imports xpub for testnet', () async {
      final result = Wallet(
        id: 'id1234',
        name: 'Test Wallet',
        network: Network.bitcoinTestnet,
        balanceSat: BigInt.zero,
        isDefault: false,
      );

      // Arrange: Set up mock responses
      when(() => mockSettingsRepository.getEnvironment())
          .thenAnswer((_) async => Environment.testnet);

      when(() => mockWalletManager.importWatchOnlyWallet(
            xpub: testXpub,
            network: Network.bitcoinTestnet,
            scriptType: testScriptType,
            label: testLabel,
          )).thenAnswer((_) async {
        return result;
      });

      // Act
      final wallet = await useCase.execute(
        xpub: testXpub,
        scriptType: testScriptType,
        label: testLabel,
      );

      // Assert
      expect(wallet, result);
      verify(() => mockSettingsRepository.getEnvironment()).called(1);
      verify(
        () => mockWalletManager.importWatchOnlyWallet(
          xpub: testXpub,
          network: Network.bitcoinTestnet,
          scriptType: testScriptType,
          label: testLabel,
        ),
      ).called(1);
    });
  });
}
