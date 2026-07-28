import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/onboarding_failure.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/create_onboarding_wallets_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCreateDefaultWalletsUsecase extends Mock
    implements CreateDefaultWalletsUsecase {}

class _MockWallet extends Mock implements Wallet {}

void main() {
  late _MockCreateDefaultWalletsUsecase createDefaultWallets;
  late CreateOnboardingWalletsUsecase usecase;

  setUp(() {
    createDefaultWallets = _MockCreateDefaultWalletsUsecase();
    usecase = CreateOnboardingWalletsUsecase(createDefaultWallets);
  });

  test('returns wallets created by the core use case', () async {
    final wallet = _MockWallet();
    when(
      () => createDefaultWallets.execute(),
    ).thenAnswer((_) async => [wallet]);

    final result = await usecase.execute();

    expect(result, isA<Ok<List<Wallet>, OnboardingFailure>>());
  });

  test('maps a core exception to a typed onboarding failure', () async {
    when(
      () => createDefaultWallets.execute(),
    ).thenThrow(CreateDefaultWalletsException('sensitive storage detail'));

    final result = await usecase.execute();

    expect(
      result,
      isA<Err<List<Wallet>, OnboardingFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<OnboardingUnexpectedFailure>(),
      ),
    );
  });

  test('treats an empty wallet result as a failure', () async {
    when(
      () => createDefaultWallets.execute(),
    ).thenAnswer((_) async => const []);

    final result = await usecase.execute();

    expect(result, isA<Err<List<Wallet>, OnboardingFailure>>());
  });
}
