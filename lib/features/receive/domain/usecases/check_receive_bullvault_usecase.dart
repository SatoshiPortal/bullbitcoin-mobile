import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';

class CheckReceiveBullVaultUsecase {
  final BullVaultFacade _bullVaultFacade;

  const CheckReceiveBullVaultUsecase(this._bullVaultFacade);

  Future<bool> execute(String walletId) async =>
      switch (await _bullVaultFacade.isBullVaultWallet(walletId)) {
        Ok(:final value) => value,
        Err() => true,
      };
}
