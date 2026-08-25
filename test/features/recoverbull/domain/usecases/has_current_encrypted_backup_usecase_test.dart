import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/recoverbull/domain/usecases/has_current_encrypted_backup_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockWallet extends Mock implements Wallet {}

const _mainnetSettings = SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'USD',
);

void main() {
  late _MockGetWalletsUsecase getWallets;
  late _MockGetSettingsUsecase getSettings;
  late HasCurrentEncryptedBackupUsecase usecase;

  setUp(() {
    getWallets = _MockGetWalletsUsecase();
    getSettings = _MockGetSettingsUsecase();
    usecase = HasCurrentEncryptedBackupUsecase(getWallets, getSettings);
    when(() => getSettings.execute()).thenAnswer((_) async => _mainnetSettings);
  });

  test(
    'returns true when the current network has an encrypted backup',
    () async {
      final wallet = _MockWallet();
      when(() => wallet.network).thenReturn(Network.bitcoinMainnet);
      when(() => wallet.latestEncryptedBackup).thenReturn(DateTime(2026));
      when(
        () => getWallets.execute(onlyDefaults: true),
      ).thenAnswer((_) async => [wallet]);

      expect(await usecase.execute(), isTrue);
    },
  );

  test('ignores an encrypted backup from another network', () async {
    final wallet = _MockWallet();
    when(() => wallet.network).thenReturn(Network.bitcoinTestnet);
    when(() => wallet.latestEncryptedBackup).thenReturn(DateTime(2026));
    when(
      () => getWallets.execute(onlyDefaults: true),
    ).thenAnswer((_) async => [wallet]);

    expect(await usecase.execute(), isFalse);
  });

  test(
    'returns false when the current wallet has no encrypted backup',
    () async {
      final wallet = _MockWallet();
      when(() => wallet.network).thenReturn(Network.bitcoinMainnet);
      when(() => wallet.latestEncryptedBackup).thenReturn(null);
      when(
        () => getWallets.execute(onlyDefaults: true),
      ).thenAnswer((_) async => [wallet]);

      expect(await usecase.execute(), isFalse);
    },
  );
}
