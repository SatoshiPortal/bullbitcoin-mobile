import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';
import '../broadcast_signed_tx_failure.dart';

class LoadBroadcastWalletsUsecase {
  final GetWalletsUsecase _get;
  LoadBroadcastWalletsUsecase({required this._get});
  @useResult
  Future<Result<List<Wallet>, BroadcastSignedTxFailure>> execute() async =>
      (await _get.execute(
        onlyBitcoin: true,
      )).mapErr((_) => const BroadcastWalletsUnavailableFailure());
}
