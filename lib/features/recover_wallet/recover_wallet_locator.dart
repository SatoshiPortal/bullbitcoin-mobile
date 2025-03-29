import 'package:bb_mobile/core/seed/domain/usecases/find_mnemonic_words_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/recover_wallet/presentation/bloc/recover_wallet_bloc.dart';
import 'package:bb_mobile/locator.dart';

class RecoverWalletLocator {
  static void setup() {
    // Blocs
    locator.registerFactory<RecoverWalletBloc>(
      () => RecoverWalletBloc(
        findMnemonicWordsUsecase: locator<FindMnemonicWordsUsecase>(),
        createDefaultWalletsUsecase: locator<CreateDefaultWalletsUsecase>(),
      ),
    );
  }
}
