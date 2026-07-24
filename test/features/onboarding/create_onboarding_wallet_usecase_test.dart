import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/onboarding_failure.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/create_onboarding_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCreateDefaultWalletsUsecase extends Mock
    implements CreateDefaultWalletsUsecase {}

class _MockWallet extends Mock implements Wallet {}

void main() {
  late _MockCreateDefaultWalletsUsecase createDefaultWalletsUsecase;
  late CreateOnboardingWalletUsecase usecase;

  setUp(() {
    createDefaultWalletsUsecase = _MockCreateDefaultWalletsUsecase();
    usecase = CreateOnboardingWalletUsecase(
      createDefaultWalletsUsecase: createDefaultWalletsUsecase,
    );
  });

  group('CreateOnboardingWalletUsecase', () {
    test(
      'maps a foreign wallet-creation failure to OnboardingWalletCreationFailure '
      'without leaking the raw exception',
      () async {
        when(
          () => createDefaultWalletsUsecase.execute(),
        ).thenThrow(Exception('BDK: descriptor derivation failed 0xdeadbeef'));

        final result = await usecase.execute();

        expect(result, isA<Err<List<Wallet>, OnboardingFailure>>());
        final failure =
            (result as Err<List<Wallet>, OnboardingFailure>).failure;
        expect(failure, isA<OnboardingWalletCreationFailure>());
        // The sanitized failure carries no raw reason for the UI to render.
        expect(failure.logMessage, isNull);
      },
    );

    test('returns Ok with the wallets on success', () async {
      final wallets = [_MockWallet()];
      when(
        () => createDefaultWalletsUsecase.execute(),
      ).thenAnswer((_) async => wallets);

      final result = await usecase.execute();

      expect(result, isA<Ok<List<Wallet>, OnboardingFailure>>());
      expect(
        (result as Ok<List<Wallet>, OnboardingFailure>).value,
        same(wallets),
      );
    });
  });
}
