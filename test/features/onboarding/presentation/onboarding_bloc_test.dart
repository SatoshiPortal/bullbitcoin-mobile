import 'package:bb_mobile/features/onboarding/domain/usecases/create_onboarding_wallet_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/recover_onboarding_wallet_usecase.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockCreateOnboardingWalletUsecase extends Mock
    implements CreateOnboardingWalletUsecase {}

class _MockRecoverOnboardingWalletUsecase extends Mock
    implements RecoverOnboardingWalletUsecase {}

void main() {
  test('reports success as soon as the default wallets exist', () async {
    final createWallets = _MockCreateOnboardingWalletUsecase();
    when(() => createWallets.execute()).thenAnswer((_) async => const Ok([]));
    final bloc = OnboardingBloc(
      createOnboardingWalletUsecase: createWallets,
      recoverOnboardingWalletUsecase: _MockRecoverOnboardingWalletUsecase(),
    );
    addTearDown(bloc.close);

    bloc.add(const OnboardingCreateNewWallet());
    final state = await bloc.stream.firstWhere((state) => state.isSuccess);

    // Nothing after wallet creation, such as the Data Backup opt-in, is
    // awaited here: that runs from the home page.
    expect(state.failure, isNull);
    verify(() => createWallets.execute()).called(1);
  });
}
