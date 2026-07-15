import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_wallets_for_network_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockWallet extends Mock implements Wallet {}

void main() {
  late _MockSettingsRepository settingsRepository;
  late _MockWalletRepository walletRepository;
  late LoadWalletsForNetworkUsecase usecase;

  setUp(() {
    settingsRepository = _MockSettingsRepository();
    walletRepository = _MockWalletRepository();
    usecase = LoadWalletsForNetworkUsecase(
      walletRepository: walletRepository,
      settingsRepository: settingsRepository,
    );

    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
  });

  test('returns the eligible Bitcoin wallets', () async {
    final wallet = _MockWallet();
    when(
      () => walletRepository.getWallets(
        onlyDefaults: false,
        onlyBitcoin: true,
        environment: Environment.mainnet,
      ),
    ).thenAnswer((_) async => [wallet]);

    final result = await usecase.execute();

    expect(
      result,
      isA<Ok<List<Wallet>, TestWalletBackupFailure>>().having(
        (result) => result.value,
        'wallets',
        [wallet],
      ),
    );
  });

  test('maps an empty wallet list to a typed load failure', () async {
    when(
      () => walletRepository.getWallets(
        onlyDefaults: false,
        onlyBitcoin: true,
        environment: Environment.mainnet,
      ),
    ).thenAnswer((_) async => const []);

    final result = await usecase.execute();

    expect(
      result,
      isA<Err<List<Wallet>, TestWalletBackupFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<TestWalletBackupLoadWalletsFailure>(),
      ),
    );
  });

  test('maps repository exceptions to a typed load failure', () async {
    when(
      () => walletRepository.getWallets(
        onlyDefaults: false,
        onlyBitcoin: true,
        environment: Environment.mainnet,
      ),
    ).thenThrow(Exception('sensitive storage detail'));

    final result = await usecase.execute();

    expect(
      result,
      isA<Err<List<Wallet>, TestWalletBackupFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<TestWalletBackupLoadWalletsFailure>(),
      ),
    );
  });
}
