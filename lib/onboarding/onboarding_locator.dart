import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/onboarding/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/onboarding/presentation/bloc/onboarding_bloc.dart';

class OnboardingLocator {
  static void setup() {
    // Blocs
    locator.registerFactory<OnboardingBloc>(
      () => OnboardingBloc(
        createDefaultWalletsUseCase: locator<CreateDefaultWalletsUseCase>(),
      ),
    );
  }
}
