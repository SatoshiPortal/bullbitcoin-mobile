import 'package:bb_mobile/features/bip85_entropy/public/bip85_parent.dart';
import 'package:get_it/get_it.dart';
import 'package:preferences/preferences.dart';

import '../data/wallet_repository.dart';
import '../domain/read_default_bip85_parent_usecase.dart';

abstract final class WalletBip85Bindings {
  static Bip85ParentReader reader(GetIt locator) =>
      () => ReadDefaultBip85ParentUsecase(
        locator<WalletRepository>(),
        locator<Preferences>(),
      ).execute();
}
