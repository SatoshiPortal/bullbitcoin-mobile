import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';

class CheckWalletSyncingUsecase {
  final WalletRepository _walletRepository;

  CheckWalletSyncingUsecase({required this._walletRepository});

  @useResult
  Result<bool, WalletFailure> execute({String? walletId}) =>
      _walletRepository.isWalletSyncing(walletId: walletId);
}
