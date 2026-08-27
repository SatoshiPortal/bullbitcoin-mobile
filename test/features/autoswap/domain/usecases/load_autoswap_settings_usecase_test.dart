import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/load_autoswap_settings_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetAutoSwapSettingsUsecase extends Mock
    implements GetAutoSwapSettingsUsecase {}

class MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class MockWalletRepository extends Mock implements WalletRepository {}

class FakeWallet extends Fake implements Wallet {
  FakeWallet({
    required this.id,
    required this.isLiquid,
    required this.isDefault,
  });

  @override
  final String id;
  @override
  final bool isLiquid;
  @override
  final bool isDefault;
}

/// A wallet id is the descriptor origin, so it embeds the master key
/// fingerprint. It must never reach [Failure.logMessage].
const _sentinelWalletId = 'wpkh([da7ab10b/84h/0h/0h])';

const _settings = SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'CAD',
);

void main() {
  late MockGetAutoSwapSettingsUsecase getAutoSwap;
  late MockGetSettingsUsecase getSettings;
  late MockWalletRepository wallets;
  late LoadAutoswapSettingsUsecase usecase;

  setUp(() {
    getAutoSwap = MockGetAutoSwapSettingsUsecase();
    getSettings = MockGetSettingsUsecase();
    wallets = MockWalletRepository();
    usecase = LoadAutoswapSettingsUsecase(
      getAutoSwapSettingsUsecase: getAutoSwap,
      getSettingsUsecase: getSettings,
      walletRepository: wallets,
    );
    when(() => getSettings.execute()).thenAnswer((_) async => _settings);
  });

  AutoswapFailure failureOf(
    Result<AutoswapSettingsData, AutoswapFailure> result,
  ) {
    expect(result, isA<Err<AutoswapSettingsData, AutoswapFailure>>());
    return (result as Err<AutoswapSettingsData, AutoswapFailure>).failure;
  }

  group('LoadAutoswapSettingsUsecase', () {
    test('returns only bitcoin wallets and the stored recipient', () async {
      when(
        () => getAutoSwap.execute(),
      ).thenAnswer((_) async => const AutoSwap(recipientWalletId: 'stored'));
      when(
        () => wallets.getWallets(environment: any(named: 'environment')),
      ).thenAnswer(
        (_) async => [
          FakeWallet(id: 'btc', isLiquid: false, isDefault: true),
          FakeWallet(id: 'lbtc', isLiquid: true, isDefault: true),
        ],
      );

      final result = await usecase.execute();

      expect(result, isA<Ok<AutoswapSettingsData, AutoswapFailure>>());
      final data = (result as Ok<AutoswapSettingsData, AutoswapFailure>).value;
      expect(data.bitcoinWallets.map((w) => w.id), ['btc']);
      expect(data.recipientWalletId, 'stored');
      expect(data.bitcoinUnit, BitcoinUnit.sats);
    });

    test(
      'falls back to the default bitcoin wallet when none is stored',
      () async {
        when(
          () => getAutoSwap.execute(),
        ).thenAnswer((_) async => const AutoSwap());
        when(
          () => wallets.getWallets(environment: any(named: 'environment')),
        ).thenAnswer(
          (_) async => [
            FakeWallet(id: 'other', isLiquid: false, isDefault: false),
            FakeWallet(id: 'default-btc', isLiquid: false, isDefault: true),
          ],
        );

        final result = await usecase.execute();

        final data =
            (result as Ok<AutoswapSettingsData, AutoswapFailure>).value;
        expect(data.recipientWalletId, 'default-btc');
      },
    );

    test('maps a throwing read to SettingsUnavailable, keeping the raw reason '
        'out of the failure', () async {
      when(() => getAutoSwap.execute()).thenThrow(
        Exception('drift read failed for $_sentinelWalletId xprv9sSecret'),
      );

      final failure = failureOf(await usecase.execute());

      expect(failure, isA<AutoswapSettingsUnavailableFailure>());
      expect(failure.logMessage, '_Exception');
      expect(failure.logMessage, isNot(contains(_sentinelWalletId)));
      expect(failure.logMessage, isNot(contains('xprv')));
    });

    test('maps a failing wallet lookup to SettingsUnavailable', () async {
      when(
        () => getAutoSwap.execute(),
      ).thenAnswer((_) async => const AutoSwap());
      when(
        () => wallets.getWallets(environment: any(named: 'environment')),
      ).thenAnswer((_) async => throw Exception('bdk exploded'));

      expect(
        failureOf(await usecase.execute()),
        isA<AutoswapSettingsUnavailableFailure>(),
      );
    });
  });
}
