import 'package:preferences/preferences.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_swap_rescue_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSettingsRepository extends Mock implements Preferences {}

void main() {
  late _MockWalletRepository wallets;
  late _MockSettingsRepository settings;
  late GetSwapRescueWalletsUsecase usecase;

  setUpAll(() => registerFallbackValue(Environment.mainnet));

  setUp(() {
    wallets = _MockWalletRepository();
    settings = _MockSettingsRepository();
    usecase = GetSwapRescueWalletsUsecase(
      walletRepository: wallets,
      settingsRepository: settings,
    );
    when(() => settings.fetch()).thenAnswer(
      (_) async => Ok(
        SettingsEntity(
          environment: Environment.testnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      ),
    );
    when(
      () => wallets.getWallets(
        environment: any(named: 'environment'),
        onlyBitcoin: any(named: 'onlyBitcoin'),
        onlyLiquid: any(named: 'onlyLiquid'),
      ),
    ).thenAnswer((_) async => const Ok(<Wallet>[]));
  });

  test(
    'a swap acting on Liquid lists Liquid wallets of the active environment',
    () async {
      expect(
        await usecase.execute(actsOnLiquid: true),
        isA<Ok<List<Wallet>, WalletFailure>>(),
      );

      verify(
        () => wallets.getWallets(
          environment: Environment.testnet,
          onlyBitcoin: false,
          onlyLiquid: true,
        ),
      ).called(1);
    },
  );

  test('a swap acting on Bitcoin lists Bitcoin wallets', () async {
    expect(
      await usecase.execute(actsOnLiquid: false),
      isA<Ok<List<Wallet>, WalletFailure>>(),
    );

    verify(
      () => wallets.getWallets(
        environment: Environment.testnet,
        onlyBitcoin: true,
        onlyLiquid: false,
      ),
    ).called(1);
  });

  test('unreadable settings are a failure, not a crash', () async {
    when(() => settings.fetch()).thenThrow(Exception('db closed'));

    final result = await usecase.execute(actsOnLiquid: true);

    expect(result, isA<Err<List<Wallet>, WalletFailure>>());
  });
}
