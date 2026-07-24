import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_sync_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';

class StartWalletSyncUsecase {
  final WalletSyncRepository _walletSyncRepository;

  StartWalletSyncUsecase({required this._walletSyncRepository});

  Future<Result<void, WalletSyncFailure>> execute({required String walletId}) =>
      _walletSyncRepository.startSync(walletId: walletId);
}
