import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_hex_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_mnemonic_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/fetch_all_derivations_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/features/bip85_entropy/presentation/cubit.dart';
import 'package:bb_mobile/locator.dart';

class Bip85EntropyLocator {
  static void setup() {
    locator.registerFactory<Bip85EntropyCubit>(
      () => Bip85EntropyCubit(
        fetchAllBip85DerivationsUsecase:
            locator<FetchAllBip85DerivationsUsecase>(),
        deriveNextBip85MnemonicFromDefaultWalletUsecase:
            locator<DeriveNextBip85MnemonicFromDefaultWalletUsecase>(),
        deriveNextBip85HexFromDefaultWalletUsecase:
            locator<DeriveNextBip85HexFromDefaultWalletUsecase>(),
        getDefaultSeedUsecase: locator<GetDefaultSeedUsecase>(),
      ),
    );
  }
}
