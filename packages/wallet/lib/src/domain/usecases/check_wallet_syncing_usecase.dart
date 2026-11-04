import 'package:primitives/primitives.dart';
import 'package:wallet/wallet.dart';
import 'package:meta/meta.dart';

class CheckWalletSyncingUsecase {
  final WalletRepository _walletRepository;

  CheckWalletSyncingUsecase({required this._walletRepository});

  @useResult
  Result<bool, WalletFailure> execute({String? walletId}) =>
      _walletRepository.isWalletSyncing(walletId: walletId);
}
