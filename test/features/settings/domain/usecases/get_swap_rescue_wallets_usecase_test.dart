import 'package:bb_mobile/features/settings/domain/usecases/get_swap_rescue_wallets_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:swaps/swaps.dart' show SwapsFailure;

class _Wallets extends Mock implements WalletInventory {}

class _Environment extends Mock implements ActiveEnvironmentReader {}

void main() {
  late _Wallets wallets;
  late _Environment environment;
  late GetSwapRescueWalletsUsecase usecase;

  setUp(() {
    wallets = _Wallets();
    environment = _Environment();
    usecase = GetSwapRescueWalletsUsecase(
      inventory: wallets,
      environment: environment,
    );
    when(environment.readActiveEnvironment)
        .thenAnswer((_) async => const Ok(Environment.testnet));
  });

  for (final (actsOnLiquid, network) in <(bool, Network)>[
    (false, BitcoinNetwork.testnet),
    (true, LiquidNetwork.testnet),
  ]) {
    test('swap rescue reads only the admitted $network accounts', () async {
      final wallet = walletRegistrationForTesting(
        id: 'destination',
        network: network,
      );
      when(() => wallets.walletsForNetwork(network))
          .thenAnswer((_) async => Ok(walletSelectionForTesting([wallet])));

      expect(
        await usecase.execute(actsOnLiquid: actsOnLiquid),
        isA<Ok<List<WalletRegistration>, SwapsFailure>>().having(
          (result) => result.value,
          'wallets',
          [wallet],
        ),
      );
      verify(() => wallets.walletsForNetwork(network)).called(1);
    });
  }

  test('a watch-only account is offered as a rescue destination', () async {
    final watchOnly = walletRegistrationForTesting(
      id: 'watch-only',
      network: BitcoinNetwork.testnet,
    );
    expect(watchOnly.signer, WalletSigner.none);
    when(() => wallets.walletsForNetwork(BitcoinNetwork.testnet))
        .thenAnswer((_) async => Ok(walletSelectionForTesting([watchOnly])));

    expect(
      await usecase.execute(actsOnLiquid: false),
      isA<Ok<List<WalletRegistration>, SwapsFailure>>().having(
        (result) => result.value,
        'wallets',
        [watchOnly],
      ),
    );
  });

  test('an incomplete inventory fails instead of offering fewer accounts',
      () async {
    final readable = walletRegistrationForTesting(
      id: 'readable',
      network: BitcoinNetwork.testnet,
    );
    when(() => wallets.walletsForNetwork(BitcoinNetwork.testnet)).thenAnswer(
      (_) async =>
          Ok(walletSelectionForTesting([readable], isComplete: false)),
    );

    expect(
      await usecase.execute(actsOnLiquid: false),
      isA<Err<List<WalletRegistration>, SwapsFailure>>(),
    );
  });

  test('unavailable inventory fails before offering a destination', () async {
    when(() => wallets.walletsForNetwork(LiquidNetwork.testnet))
        .thenAnswer((_) async => const Err(UnreadableWalletFailure()));

    expect(
      await usecase.execute(actsOnLiquid: true),
      isA<Err<List<WalletRegistration>, SwapsFailure>>(),
    );
  });
}
