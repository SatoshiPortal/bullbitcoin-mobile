import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWallet extends Mock implements Wallet {}

class _MockSettings extends Mock implements SettingsEntity {}

/// The load path behind the wallet home screen. Before #1895 a failure here
/// threw `GetWalletsException('$e')` — the raw reason stringified into an
/// exception message that the bloc then stored in an untyped `Object? error`.
void main() {
  late _MockWalletRepository walletRepository;
  late _MockSettingsRepository settingsRepository;
  late GetWalletsUsecase usecase;

  setUp(() {
    walletRepository = _MockWalletRepository();
    settingsRepository = _MockSettingsRepository();
    usecase = GetWalletsUsecase(
      walletRepository: walletRepository,
      settingsRepository: settingsRepository,
    );
    final settings = _MockSettings();
    when(() => settings.environment).thenReturn(Environment.mainnet);
    when(settingsRepository.fetch).thenAnswer((_) async => settings);
  });

  test('returns the wallets it was given', () async {
    final wallet = _MockWallet();
    when(
      () => walletRepository.getWallets(
        environment: any(named: 'environment'),
        onlyDefaults: any(named: 'onlyDefaults'),
        onlyBitcoin: any(named: 'onlyBitcoin'),
        onlyLiquid: any(named: 'onlyLiquid'),
        sync: any(named: 'sync'),
      ),
    ).thenAnswer((_) async => Ok<List<Wallet>, WalletFailure>([wallet]));

    expect((await usecase.execute() as Ok).value, [wallet]);
  });

  test('an empty result is NoWalletsFoundFailure, not an empty list', () async {
    // The router treats this as "not onboarded yet" and redirects, so it has
    // to be distinguishable from a real read.
    when(
      () => walletRepository.getWallets(
        environment: any(named: 'environment'),
        onlyDefaults: any(named: 'onlyDefaults'),
        onlyBitcoin: any(named: 'onlyBitcoin'),
        onlyLiquid: any(named: 'onlyLiquid'),
        sync: any(named: 'sync'),
      ),
    ).thenAnswer((_) async => const Ok<List<Wallet>, WalletFailure>([]));

    final result = await usecase.execute();

    expect((result as Err).failure, isA<NoWalletsFoundFailure>());
  });

  test('forwards a repository failure without rewrapping it', () async {
    when(
      () => walletRepository.getWallets(
        environment: any(named: 'environment'),
        onlyDefaults: any(named: 'onlyDefaults'),
        onlyBitcoin: any(named: 'onlyBitcoin'),
        onlyLiquid: any(named: 'onlyLiquid'),
        sync: any(named: 'sync'),
      ),
    ).thenAnswer(
      (_) async => const Err<List<Wallet>, WalletFailure>(
        WalletStorageFailure('getWallets failed: SqliteException'),
      ),
    );

    final result = await usecase.execute();

    expect((result as Err).failure, isA<WalletStorageFailure>());
  });

  test('sanitizes a throwing settings read', () async {
    when(
      settingsRepository.fetch,
    ).thenThrow(StateError('SqliteException(13): disk image is malformed'));

    final result = await usecase.execute();

    final failure = (result as Err).failure as WalletFailure;
    expect(failure, isA<WalletStorageFailure>());
    // The raw reason belongs in the log, never in a value presentation holds.
    expect(failure.logMessage, isNot(contains('disk image is malformed')));
  });
}
