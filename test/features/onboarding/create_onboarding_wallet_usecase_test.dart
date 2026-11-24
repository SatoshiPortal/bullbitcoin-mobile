import 'package:primitives/primitives.dart';
import 'package:provisioning/provisioning.dart';
import 'package:secrets/secrets.dart' show WalletRegistration;
import 'package:onboarding/onboarding.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/create_onboarding_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCreateDefaultWalletsUsecase extends Mock
    implements DefaultWalletProvisioning {}

void main() {
  late _MockCreateDefaultWalletsUsecase createDefaultWalletsUsecase;
  late CreateOnboardingWalletUsecase usecase;

  setUp(() {
    createDefaultWalletsUsecase = _MockCreateDefaultWalletsUsecase();
    usecase = CreateOnboardingWalletUsecase(
      defaultWallets: createDefaultWalletsUsecase,
    );
  });

  group('CreateOnboardingWalletUsecase', () {
    test('maps a foreign wallet-setup failure to OnboardingWalletSetupFailure '
        'without leaking the raw exception', () async {
      when(() => createDefaultWalletsUsecase.execute())
          .thenAnswer((_) async => const Err(DefaultWalletCreationFailure()));

      final result = await usecase.execute();

      expect(result, isA<Err<void, OnboardingFailure>>());
      final failure = (result as Err<void, OnboardingFailure>).failure;
      expect(failure, isA<OnboardingWalletSetupFailure>());
      // The sanitized failure carries no raw reason for the UI to render.
      expect(failure.logMessage, isNull);
    });

    test('reports success without exporting wallet objects', () async {
      final wallets = <WalletRegistration>[];
      when(() => createDefaultWalletsUsecase.execute())
          .thenAnswer((_) async => Ok(wallets));

      final result = await usecase.execute();

      expect(result, isA<Ok<void, OnboardingFailure>>());
    });
  });
}
