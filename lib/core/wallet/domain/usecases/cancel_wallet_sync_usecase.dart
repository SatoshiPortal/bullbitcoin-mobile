import 'package:bb_mobile/core/wallet/domain/repositories/wallet_sync_repository.dart';

class CancelWalletSyncUsecase {
  final WalletSyncRepository _walletSyncRepository;

  CancelWalletSyncUsecase({required this._walletSyncRepository});

  Future<void> execute({required String walletId}) =>
      _walletSyncRepository.cancelSync(walletId: walletId);
}
