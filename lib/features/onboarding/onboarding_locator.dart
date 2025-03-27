import 'package:bb_mobile/core/domain/usecases/find_mnemonic_words_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/locator.dart';

class OnboardingLocator {
  static void setup() {
    // Blocs
    locator.registerFactory<OnboardingBloc>(
      () => OnboardingBloc(
        createDefaultWalletsUsecase: locator<CreateDefaultWalletsUsecase>(),
        findMnemonicWordsUsecase: locator<FindMnemonicWordsUsecase>(),
      ),
    );
  }
}
