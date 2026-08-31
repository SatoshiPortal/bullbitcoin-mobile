import 'package:bb_mobile/core/wallet/domain/wallet_visibility_port.dart';

class SetWalletHiddenUsecase {
  final WalletVisibilityPort _walletVisibilityPort;

  const SetWalletHiddenUsecase(this._walletVisibilityPort);

  Future<void> execute({required String walletId, required bool isHidden}) =>
      _walletVisibilityPort.setHidden(walletId: walletId, isHidden: isHidden);
}
