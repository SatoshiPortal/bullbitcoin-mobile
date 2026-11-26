import 'package:swaps/order_swaps.dart';
import 'package:secrets/testing.dart';
import 'package:preferences/preferences.dart';
import 'package:swaps/swaps.dart' hide Environment;
import 'package:primitives/primitives.dart';
import 'package:swap_feature/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetAutoSwapSettingsUsecase extends Mock implements AutoSwapSettings {}

class MockGetSettingsUsecase extends Mock implements Preferences {}

class MockWalletRepository extends Mock implements LoadSwapWalletsUsecase {}

SwapWallet fakeWallet({
  required String id,
  required bool isLiquid,
  required bool isDefault,
}) => SwapWallet(
  walletRegistrationForTesting(
    id: id,
    network: isLiquid ? LiquidNetwork.mainnet : BitcoinNetwork.mainnet,
    isDefault: isDefault,
  ),
  null,
  false,
);

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
      autoSwapSettings: getAutoSwap,
      getSettingsUsecase: getSettings,
      walletRepository: wallets,
    );
    when(() => getSettings.fetch()).thenAnswer((_) async => Ok(_settings));
  });

  AutoswapFailure failureOf(
    Result<AutoswapSettingsData, AutoswapFailure> result,
  ) {
    expect(result, isA<Err<AutoswapSettingsData, AutoswapFailure>>());
    return (result as Err<AutoswapSettingsData, AutoswapFailure>).failure;
  }

  group('LoadAutoswapSettingsUsecase', () {
    test('does not query wallets when settings reject the network', () async {
      when(getAutoSwap.readAutoSwap)
          .thenAnswer((_) async => const Err(SwapsUnsupportedNetworkFailure()));

      expect(
        failureOf(await usecase.execute()),
        isA<AutoswapUnsupportedNetworkFailure>(),
      );
      verifyNever(() => wallets.execute(NetworkEnv.mainnet));
    });

    test('returns only bitcoin wallets and the stored recipient', () async {
      when(() => getAutoSwap.readAutoSwap()).thenAnswer(
        (_) async => const Ok(AutoSwap(recipientWalletId: 'stored')),
      );
      when(() => wallets.execute(NetworkEnv.mainnet)).thenAnswer(
        (_) async => Ok<List<SwapWallet>, SwapFailure>([
          fakeWallet(id: 'btc', isLiquid: false, isDefault: true),
          fakeWallet(id: 'lbtc', isLiquid: true, isDefault: true),
        ]),
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
        when(() => getAutoSwap.readAutoSwap())
            .thenAnswer((_) async => const Ok(AutoSwap()));
        when(() => wallets.execute(NetworkEnv.mainnet)).thenAnswer(
          (_) async => Ok<List<SwapWallet>, SwapFailure>([
            fakeWallet(id: 'other', isLiquid: false, isDefault: false),
            fakeWallet(id: 'default-btc', isLiquid: false, isDefault: true),
          ]),
        );

        final result = await usecase.execute();

        final data =
            (result as Ok<AutoswapSettingsData, AutoswapFailure>).value;
        expect(data.recipientWalletId, 'default-btc');
      },
    );

    test('maps a throwing read to SettingsUnavailable, keeping the raw reason '
        'out of the failure', () async {
      when(() => getAutoSwap.readAutoSwap()).thenThrow(
        Exception('drift read failed for $_sentinelWalletId xprv9sSecret'),
      );

      final failure = failureOf(await usecase.execute());

      expect(failure, isA<AutoswapSettingsUnavailableFailure>());
      expect(failure.logMessage, '_Exception');
      expect(failure.logMessage, isNot(contains(_sentinelWalletId)));
      expect(failure.logMessage, isNot(contains('xprv')));
    });

    test('maps a failing wallet lookup to SettingsUnavailable', () async {
      when(() => getAutoSwap.readAutoSwap())
          .thenAnswer((_) async => const Ok(AutoSwap()));
      when(() => wallets.execute(NetworkEnv.mainnet))
          .thenAnswer((_) async => throw Exception('bdk exploded'));

      expect(
        failureOf(await usecase.execute()),
        isA<AutoswapSettingsUnavailableFailure>(),
      );
    });
  });
}
